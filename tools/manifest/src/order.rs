//! The order the layers build in, resolved from the graph.
//!
//! Declaration order used to be the build order, which made every
//! ordering fact in the repository a fact about where a line sits in
//! the image file. A `requires` already says "after the module that
//! provides this", so the list no longer has to repeat it, and the two
//! can no longer disagree.
//!
//! Determinism is not negotiable: a reshuffle is a full rebuild, so the
//! same list has to produce the same order on every machine. Kahn's
//! algorithm with a fixed tie-break does that — never a hash map
//! iteration, never file system order.

use crate::diag::{Issue, Issues};
use crate::list::{Entry, Image};
use crate::module::Module;
use std::cmp::Reverse;
use std::collections::{BTreeMap, BinaryHeap};

/// The build order, as list indices.
///
/// Constraints, in the order they bind:
///
/// 1. a provider builds before anything that `requires` it, or reads a
///    file it provides. Hard: a consumer that runs first would find the
///    capability missing.
/// 2. a provider builds before anything declaring `after` it, when it is
///    enabled at all. Soft: ordering and cache preference, never an
///    error.
/// 3. ungated modules build before gated ones, so nothing lands below
///    `ARG FLAVOR` and gets built once per flavor for no reason.
/// 4. anything still tied builds in declaration order.
pub fn sort(image: &Image, modules: &[Module], issues: &mut Issues) -> Vec<usize> {
    let by_entry: Vec<Option<&Module>> = image
        .entries
        .iter()
        .map(|e| {
            modules
                .iter()
                .find(|m| m.path == e.path && m.flavor == e.flavor)
        })
        .collect();

    // First provider wins: a capability offered twice is already an
    // error, and picking one keeps the order defined while it is fixed.
    let mut offered: BTreeMap<&str, usize> = BTreeMap::new();
    for (index, module) in by_entry.iter().enumerate() {
        let Some(module) = module else { continue };
        for decl in module.provides.iter().chain(module.provides_files.iter()) {
            offered.entry(decl.name.as_str()).or_insert(index);
        }
    }

    let n = image.entries.len();
    let mut waits_on: Vec<Vec<usize>> = vec![Vec::new(); n];
    for (index, module) in by_entry.iter().enumerate() {
        let Some(module) = module else { continue };
        let hard = module.requires.iter().chain(module.requires_files.iter());
        for decl in hard {
            if let Some(&provider) = offered.get(decl.name.as_str()) {
                if provider != index {
                    waits_on[index].push(provider);
                }
            }
        }
        for decl in &module.after {
            let Some(&provider) = offered.get(decl.name.as_str()) else {
                continue;
            };
            // A preference never drags an ungated module below the
            // flavor gate: that would cost a layer per flavor to satisfy
            // something that is allowed to go unsatisfied.
            let drags_below_gate =
                module.flavor.is_none() && by_entry[provider].is_some_and(|p| p.flavor.is_some());
            if provider != index && !drags_below_gate {
                waits_on[index].push(provider);
            }
        }
        waits_on[index].sort_unstable();
        waits_on[index].dedup();
    }

    let mut blocking: Vec<Vec<usize>> = vec![Vec::new(); n];
    let mut remaining: Vec<usize> = vec![0; n];
    for (index, providers) in waits_on.iter().enumerate() {
        remaining[index] = providers.len();
        for &provider in providers {
            blocking[provider].push(index);
        }
    }

    // The tie-break, and the only thing that decides between two modules
    // the graph says nothing about: ungated first, then declaration
    // order. Reverse turns the max-heap into a min-heap.
    let key = |index: usize| {
        let gated = u8::from(by_entry[index].is_some_and(|m| m.flavor.is_some()));
        Reverse((gated, index))
    };

    let mut ready: BinaryHeap<Reverse<(u8, usize)>> = (0..n)
        .filter(|&index| remaining[index] == 0)
        .map(key)
        .collect();

    let mut order = Vec::with_capacity(n);
    while let Some(Reverse((_, index))) = ready.pop() {
        order.push(index);
        for &waiting in &blocking[index] {
            remaining[waiting] -= 1;
            if remaining[waiting] == 0 {
                ready.push(key(waiting));
            }
        }
    }

    if order.len() < n {
        report_cycle(image, &by_entry, &waits_on, &remaining, issues);
        // Declaration order for whatever is left, so the run still
        // reaches every other check instead of stopping at this one.
        order.extend((0..n).filter(|index| remaining[*index] > 0));
    }
    order
}

/// Rearranges the list and the loaded manifests into build order, so
/// everything downstream — the generated Containerfile, the resolved
/// summary, the finalize hook order — sees one order and none of them
/// has to know it was ever different.
pub fn apply(image: &mut Image, modules: &mut [Module], order: &[usize]) {
    let mut taken: Vec<Option<Entry>> = image.entries.drain(..).map(Some).collect();
    image.entries = order
        .iter()
        .filter_map(|&index| taken[index].take())
        .collect();
    modules.sort_by_key(|m| {
        image.entries
            .iter()
            .position(|e| e.path == m.path && e.flavor == m.flavor)
            .unwrap_or(usize::MAX)
    });
}

/// Everything left when the sort runs out of ready modules is waiting on
/// something else that is also waiting, so the message names the edges
/// rather than just reporting that an order could not be found.
fn report_cycle(
    image: &Image,
    by_entry: &[Option<&Module>],
    waits_on: &[Vec<usize>],
    remaining: &[usize],
    issues: &mut Issues,
) {
    let name = |index: usize| match by_entry[index].and_then(|m| m.flavor.as_deref()) {
        Some(flavor) => format!("{} [{flavor}]", image.entries[index].path),
        None => image.entries[index].path.clone(),
    };

    let mut issue = Issue::new("the module graph has a cycle", &image.file, &image.text).help(
        "a requirement implies ordering, so a cycle has no build order at all; \
         drop one of the edges, or split the module that closes it",
    );
    for (index, providers) in waits_on.iter().enumerate() {
        if remaining[index] == 0 {
            continue;
        }
        let blocked: Vec<String> = providers
            .iter()
            .filter(|&&provider| remaining[provider] > 0)
            .map(|&provider| format!("`{}`", name(provider)))
            .collect();
        issue = issue.at(
            image.entries[index].span,
            format!("waits on {}", blocked.join(", ")),
        );
    }
    issues.push(issue);
}
