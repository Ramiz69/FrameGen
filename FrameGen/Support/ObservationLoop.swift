//
//  ObservationLoop.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Observation

/// Calls `apply` now and again after any `@Observable` property it read changes.
/// Changes that arrive together are coalesced into a single call on the main actor.
final class ObservationLoop {

    private let apply: () -> Void
    private var isCancelled = false

    init(_ apply: @escaping () -> Void) {
        self.apply = apply
        track()
    }

    func cancel() {
        isCancelled = true
    }

    private func track() {
        guard !isCancelled else { return }

        withObservationTracking(apply) { [weak self] in
            Task { @MainActor in
                self?.track()
            }
        }
    }

}
