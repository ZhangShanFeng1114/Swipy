//
// Swipy is a SwiftUI library for making swipe actions.
//
// See the GitHub repo for documentation:
// https://github.com/rohanrhu/Swipy
//
// Copyright (C) 2024, Oğuzhan Eroğlu (https://meowingcat.io)
// Licensed under the MIT License.
// You may obtain a copy of the License at: https://opensource.org/licenses/MIT
// See the LICENSE file for more information.
//

import SwiftUI
import UIKit

public struct SwipyHorizontalMargin: Sendable {
    public let leading: Double
    public let trailing: Double

    public init(leading: Double, trailing: Double) {
        self.leading = leading
        self.trailing = trailing
    }
}

public enum SwipySwipeEdge: Sendable {
    case leading
    case trailing
}

public enum SwipyRepeatedSwipeBehavior: Sendable {
    case none
    case collapseAndSuppressUntilEnd
}

public enum SwipyActionHeight: Sendable {
    case large
    case small
}

private enum SwipyActionMetrics {
    static let smallHeight: CGFloat = 45
    static let smallCornerRadius: CGFloat = 24
}

private struct SwipyActionStyle {
    let height: CGFloat?
    let cornerRadius: CGFloat?

    static let none = SwipyActionStyle(height: nil, cornerRadius: nil)
}

private struct SwipyActionStyleKey: EnvironmentKey {
    static let defaultValue = SwipyActionStyle.none
}

private extension EnvironmentValues {
    var swipyActionStyle: SwipyActionStyle {
        get { self[SwipyActionStyleKey.self] }
        set { self[SwipyActionStyleKey.self] = newValue }
    }

    var swipyScrollLockState: SwipyScrollLockState? {
        get { self[SwipyScrollLockStateKey.self] }
        set { self[SwipyScrollLockStateKey.self] = newValue }
    }
}

@MainActor
private final class SwipyScrollLockState: ObservableObject {
    @Published private(set) var isLocked = false

    private var lockIDs: Set<UUID> = []

    func setLocked(_ locked: Bool, for id: UUID) {
        if locked {
            lockIDs.insert(id)
        } else {
            lockIDs.remove(id)
        }

        isLocked = !lockIDs.isEmpty
    }
}

private struct SwipyScrollLockStateKey: EnvironmentKey {
    static let defaultValue: SwipyScrollLockState? = nil
}

private struct SwipyScrollLockModifier: ViewModifier {
    @StateObject private var scrollLockState = SwipyScrollLockState()

    let additionalLock: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let lockedContent = content.environment(\.swipyScrollLockState, scrollLockState)

        if #available(iOS 16.0, *) {
            lockedContent.scrollDisabled(additionalLock || scrollLockState.isLocked)
        } else {
            lockedContent
        }
    }
}

public extension View {
    func swipyScrollLock(_ additionalLock: Bool = false) -> some View {
        modifier(SwipyScrollLockModifier(additionalLock: additionalLock))
    }
}

public struct SwipyDirectionLock: Sendable {
    public let minimumDistance: Double
    public let horizontalDominance: Double
    public let verticalDominance: Double

    public init(
        minimumDistance: Double = 8,
        horizontalDominance: Double = 1.15,
        verticalDominance: Double = 1.05
    ) {
        self.minimumDistance = minimumDistance
        self.horizontalDominance = horizontalDominance
        self.verticalDominance = verticalDominance
    }
}

public struct SwipySwipeBehavior: Sendable {
    public typealias Decider = @MainActor @Sendable (SwipyModel, CGSize, CGSize) -> Bool

    public let decider: Decider

    public init(decider: @escaping Decider) {
        self.decider = decider
    }

    public static let normal = SwipySwipeBehavior(decider: { model, translation, velocity in
        !(!model.isSwiped && !model.isSwiping && (velocity.width > -200 || translation.width > -50))
    })

    public static let soft = SwipySwipeBehavior(decider: { model, translation, velocity in
        !(!model.isSwiped && !model.isSwiping && (velocity.width > -100 || translation.width > -25))
    })

    public static let hard = SwipySwipeBehavior(decider: { model, translation, velocity in
        !(!model.isSwiped && !model.isSwiping && (velocity.width > -400 || translation.width > -100))
    })

    public static let straight = SwipySwipeBehavior(decider: { _, _, _ in true })

    public static let disabled = SwipySwipeBehavior(decider: { _, _, _ in false })

    public func or(_ combiningBehavior: Self) -> Self {
        .init { model, translation, velocity in
            decider(model, translation, velocity) || combiningBehavior.decider(model, translation, velocity)
        }
    }

    public func and(_ combiningBehavior: Self) -> Self {
        .init { model, translation, velocity in
            decider(model, translation, velocity) && combiningBehavior.decider(model, translation, velocity)
        }
    }

    public func not(_ combiningBehavior: Self) -> Self {
        .init { model, translation, velocity in
            decider(model, translation, velocity) && !combiningBehavior.decider(model, translation, velocity)
        }
    }

    public static func custom(_ decider: @escaping Decider = { model, _, _ in model.isSwiped || model.isSwiping }) -> Self {
        .init(decider: decider)
    }

    public static func swiping() -> Self {
        .init { model, _, _ in model.isSwiping }
    }

    public static func swiped() -> Self {
        .init { model, _, _ in model.isSwiped }
    }

    public static func offset(_ offset: Double) -> Self {
        .init { _, translation, _ in
            abs(translation.width) > offset
        }
    }

    public static func velocity(_ velocity: Double) -> Self {
        .init { _, _, velocityValue in
            abs(velocityValue.width) > velocity
        }
    }
}

public struct SwipyScrollBehavior: Sendable {
    public typealias Decider = @MainActor @Sendable (SwipyModel, CGSize, CGSize) -> Bool

    public let decider: Decider

    public init(decider: @escaping Decider) {
        self.decider = decider
    }

    public static let normal = Self(decider: { model, translation, _ in
        !model.isSwiped && !model.isSwiping && abs(translation.height) > 10
    })

    public static let soft = Self(decider: { model, translation, _ in
        !model.isSwiped && !model.isSwiping && abs(translation.height) > 5
    })

    public static let hard = Self(decider: { model, translation, _ in
        !model.isSwiped && !model.isSwiping && abs(translation.height) > 20
    })

    public static let disabled = SwipyScrollBehavior(decider: { _, _, _ in false })

    public func or(_ combiningBehavior: Self) -> Self {
        .init { model, translation, velocity in
            decider(model, translation, velocity) || combiningBehavior.decider(model, translation, velocity)
        }
    }

    public func and(_ combiningBehavior: Self) -> Self {
        .init { model, translation, velocity in
            decider(model, translation, velocity) && combiningBehavior.decider(model, translation, velocity)
        }
    }

    public func not(_ combiningBehavior: Self) -> Self {
        .init { model, translation, velocity in
            decider(model, translation, velocity) && !combiningBehavior.decider(model, translation, velocity)
        }
    }

    public static func custom(_ decider: @escaping Decider = { model, _, _ in model.isSwiped || model.isSwiping }) -> Self {
        .init(decider: decider)
    }

    public static func swiping() -> Self {
        .init { model, _, _ in model.isSwiping }
    }

    public static func swiped() -> Self {
        .init { model, _, _ in model.isSwiped }
    }

    public static func offset(_ offset: Double) -> Self {
        .init { _, translation, _ in
            abs(translation.height) > offset
        }
    }

    public static func velocity(_ velocity: Double) -> Self {
        .init { _, _, velocityValue in
            abs(velocityValue.height) > velocity
        }
    }
}

public struct SwipyDefaults {
    public static let swipeActionsMargin: SwipyHorizontalMargin = SwipyHorizontalMargin(leading: 0, trailing: 0)
    public static let swipeThreshold: @MainActor @Sendable (SwipyModel) -> Double = { $0.swipeActionsWidth }
    public static let leadingSwipeThreshold: @MainActor @Sendable (SwipyModel) -> Double = { $0.leadingSwipeActionsWidth }
    public static let swipeCloseThreshold: @MainActor @Sendable (SwipyModel, SwipySwipeEdge) -> Double = { model, edge in
        let actionWidth = model.swipeActionsWidth(for: edge)
        let closeRetainThreshold = max(112, actionWidth * 0.90)
        return min(closeRetainThreshold, max(actionWidth - 12, 0))
    }
    public static let swipeBehavior: SwipySwipeBehavior = .normal
    public static let scrollBehavior: SwipyScrollBehavior = .normal
    public static let repeatedSwipeBehavior: SwipyRepeatedSwipeBehavior = .collapseAndSuppressUntilEnd
    public static let directionLock: SwipyDirectionLock = .init()
    public static let actionHeight: SwipyActionHeight = .large
    public static let swipeActions: @Sendable () -> EmptyView = { EmptyView() }
}

@MainActor
public class SwipyModel: ObservableObject {
    @Published public var swipeOffset: CGSize = .zero
    @Published public var isSwiping: Bool = false
    @Published public var isScrolling: Bool = false
    @Published public var isSwiped: Bool = false
    @Published public var swipedEdge: SwipySwipeEdge?
    @Published public var swipeActionsWidth: Double = 0.0
    @Published public var leadingSwipeActionsWidth: Double = 0.0
    @Published public var trailingSwipeActionsWidth: Double = 0.0
    @Published public var contentSize: CGSize?

    @Published public var swipeActionsMargin = SwipyDefaults.swipeActionsMargin
    @Published public var swipeThreshold: @MainActor @Sendable (SwipyModel) -> Double = SwipyDefaults.swipeThreshold
    @Published public var leadingSwipeThreshold: @MainActor @Sendable (SwipyModel) -> Double = SwipyDefaults.leadingSwipeThreshold
    @Published public var swipeCloseThreshold: @MainActor @Sendable (SwipyModel, SwipySwipeEdge) -> Double = SwipyDefaults.swipeCloseThreshold
    @Published public var swipeBehavior: SwipySwipeBehavior = SwipyDefaults.swipeBehavior
    @Published public var scrollBehavior: SwipyScrollBehavior = SwipyDefaults.scrollBehavior
    @Published public var repeatedSwipeBehavior: SwipyRepeatedSwipeBehavior = SwipyDefaults.repeatedSwipeBehavior
    @Published public var directionLock: SwipyDirectionLock = SwipyDefaults.directionLock

    public init() {}
    
    public func swipe(_ edge: SwipySwipeEdge = .trailing) {
        swipedEdge = edge
        isSwiped = true
        swipeOffset.width = swipedOffset(for: edge)
    }
    
    public func unswipe() {
        swipedEdge = nil
        isSwiped = false
        isSwiping = false
        isScrolling = false
        swipeOffset = .zero
    }

    public func swipeActionsWidth(for edge: SwipySwipeEdge) -> Double {
        switch edge {
        case .leading:
            leadingSwipeActionsWidth
        case .trailing:
            trailingSwipeActionsWidth
        }
    }

    public func revealWidth(for edge: SwipySwipeEdge) -> Double {
        let actionsWidth = swipeActionsWidth(for: edge)

        guard actionsWidth > 0 else {
            return 0
        }

        switch edge {
        case .leading:
            return actionsWidth + swipeActionsMargin.leading
        case .trailing:
            return actionsWidth + swipeActionsMargin.trailing
        }
    }

    public func swipeThreshold(for edge: SwipySwipeEdge) -> Double {
        switch edge {
        case .leading:
            return leadingSwipeThreshold(self)
        case .trailing:
            return swipeThreshold(self)
        }
    }

    public func closeThreshold(for edge: SwipySwipeEdge) -> Double {
        swipeCloseThreshold(self, edge)
    }

    public func swipedOffset(for edge: SwipySwipeEdge) -> Double {
        switch edge {
        case .leading:
            return revealWidth(for: .leading)
        case .trailing:
            return -revealWidth(for: .trailing)
        }
    }
}

public struct SwipyTouchableDisabledStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(.clear)
    }
}

public struct Swipy<C, A>: View where C: View, A: View {
    public let content: (SwipyModel) -> C
    public let leadingActions: () -> AnyView
    public let actions: () -> A
    public let actionHeight: SwipyActionHeight

    @Binding public var isSwipingAnItem: Bool
    @Environment(\.swipyScrollLockState) private var scrollLockState

    @StateObject public var model: SwipyModel

    // Keep per-frame drag movement local so complex rows do not observe every offset tick.
    @State private var interactiveOffsetWidth: Double = 0.0
    @State private var gestureStartOffsetWidth: Double = 0.0
    @State private var gestureAxis: SwipyGestureAxis?
    @State private var activeSwipeEdge: SwipySwipeEdge?
    @State private var isCurrentGestureSuppressed = false
    @State private var scrollLockID = UUID()
    @State private var scrollLockGeneration = 0

    public var body: some View {
        let currentOffsetWidth = model.isSwiping ? interactiveOffsetWidth : model.swipeOffset.width

        content(model)
            .disabled(model.isSwiping || model.isSwiped)
            .buttonStyle(SwipyTouchableDisabledStyle())
            .background(
                SwipySizeReader { size in
                    model.contentSize = size
                }
            )
            .offset(x: currentOffsetWidth)
            .background(alignment: .topLeading) {
                actionsLayer(offsetWidth: currentOffsetWidth)
            }
        .environmentObject(model)
        .onChange(of: model.isSwiping) { newValue in
            updateSwipeLock(newValue)
        }
        .onChange(of: model.leadingSwipeActionsWidth) { _ in
            syncSwipedOffsetIfNeeded()
        }
        .onChange(of: model.trailingSwipeActionsWidth) { _ in
            syncSwipedOffsetIfNeeded()
        }
        .modifier {
            if #available(iOS 18, *) {
                $0.gesture(
                    SimultaneousSwipeGesture(
                        onBegan: onSwipeBegan,
                        onChanged: onSwipeChanged,
                        onEnded: onSwipeEnded
                    )
                )
            } else {
                $0.simultaneousGesture(
                    DragGesture()
                        .onChanged(onDragChanged)
                        .onEnded(onDragEnded)
                )
            }
        }
        .onDisappear {
            isSwipingAnItem = false
            scrollLockGeneration += 1
            scrollLockState?.setLocked(false, for: scrollLockID)
        }
    }

    private func updateSwipeLock(_ isSwiping: Bool, delayed: Bool = true) {
        isSwipingAnItem = isSwiping
        scrollLockGeneration += 1

        let generation = scrollLockGeneration

        guard isSwiping else {
            scrollLockState?.setLocked(false, for: scrollLockID)
            return
        }

        guard delayed else {
            scrollLockState?.setLocked(true, for: scrollLockID)
            return
        }

        Task { @MainActor in
            await Task.yield()

            guard scrollLockGeneration == generation, model.isSwiping else {
                return
            }

            scrollLockState?.setLocked(true, for: scrollLockID)
        }
    }

    @ViewBuilder
    private func actionsLayer(offsetWidth: Double) -> some View {
        let contentSize = model.contentSize ?? .zero
        let layerHeight = contentSize.height
        let actionStyle = resolvedActionStyle(contentHeight: layerHeight)
        let actionHeight = actionStyle.height ?? layerHeight

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                leadingActions()
                    .environment(\.swipyActionStyle, actionStyle)
                    .frame(height: actionHeight)
                    .background(
                        SwipySizeReader { size in
                            model.leadingSwipeActionsWidth = size.width
                        }
                    )
                Spacer(minLength: model.swipeActionsMargin.leading)
            }
            .frame(width: contentSize.width, height: layerHeight, alignment: .leading)
            .opacity(actionOpacity(for: .leading, offsetWidth: offsetWidth))

            HStack(spacing: 0) {
                Spacer(minLength: model.swipeActionsMargin.trailing)
                actions()
                    .environment(\.swipyActionStyle, actionStyle)
                    .frame(height: actionHeight)
                    .background(
                        SwipySizeReader { size in
                            model.trailingSwipeActionsWidth = size.width
                            model.swipeActionsWidth = size.width
                        }
                    )
            }
            .frame(width: contentSize.width, height: layerHeight, alignment: .trailing)
            .opacity(actionOpacity(for: .trailing, offsetWidth: offsetWidth))
        }
        .frame(width: contentSize.width, height: layerHeight, alignment: .topLeading)
    }

    private func resolvedActionStyle(contentHeight: CGFloat) -> SwipyActionStyle {
        switch actionHeight {
        case .large:
            return .none
        case .small:
            return SwipyActionStyle(
                height: min(SwipyActionMetrics.smallHeight, contentHeight),
                cornerRadius: SwipyActionMetrics.smallCornerRadius
            )
        }
    }

    private func actionOpacity(for edge: SwipySwipeEdge, offsetWidth: Double) -> Double {
        let revealWidth = max(model.revealWidth(for: edge), 1)

        switch edge {
        case .leading:
            return min(1, max(0, offsetWidth) / revealWidth)
        case .trailing:
            return min(1, max(0, -offsetWidth) / revealWidth)
        }
    }

    private func onSwipeBegan(_ recognizer: UILongPressGestureRecognizer) {
        resetGestureTracking()
    }

    private func onSwipeChanged(_ recognizer: UILongPressGestureRecognizer, _ translation: CGSize, _ velocity: CGSize) {
        handleGestureChanged(translation: translation, velocity: velocity)
    }

    private func onSwipeEnded(_ recognizer: UILongPressGestureRecognizer, _ translation: CGSize, _ velocity: CGSize) {
        handleGestureEnded(translation: translation, velocity: velocity)
    }

    private func onDragChanged(_ value: DragGesture.Value) {
        let velocity = CGSize(width: value.velocity.width, height: value.velocity.height)
        handleGestureChanged(translation: value.translation, velocity: velocity)
    }

    private func onDragEnded(_ gesture: DragGesture.Value) {
        let velocity = CGSize(width: gesture.velocity.width, height: gesture.velocity.height)
        handleGestureEnded(translation: gesture.translation, velocity: velocity)
    }

    private func handleGestureChanged(translation: CGSize, velocity: CGSize) {
        if model.isScrolling || isCurrentGestureSuppressed { return }

        guard lockGestureAxisIfNeeded(translation: translation, velocity: velocity) else {
            return
        }

        guard gestureAxis == .horizontal else {
            return
        }

        let edge = translation.width >= 0 ? SwipySwipeEdge.leading : .trailing

        if shouldCollapseAndSuppressRepeatedSwipe(edge: edge) {
            collapseAndSuppressCurrentGesture()
            return
        }

        if !canSwipe(edge) && !model.isSwiped {
            return
        }

        if activeSwipeEdge == nil {
            activeSwipeEdge = edge
        }

        guard canStartSwipe(edge: edge, translation: translation, velocity: velocity) else {
            return
        }

        if !model.isSwiping {
            model.isSwiping = true
        }

        interactiveOffsetWidth = clampedOffset(gestureStartOffsetWidth + translation.width)
    }

    private func handleGestureEnded(translation: CGSize, velocity: CGSize) {
        guard !isCurrentGestureSuppressed else {
            model.isSwiping = false
            model.isScrolling = false
            updateSwipeLock(false)
            resetGestureTracking()
            return
        }

        guard gestureAxis == .horizontal else {
            model.isSwiping = false
            model.isScrolling = false
            resetGestureTracking()
            return
        }

        let targetEdge = targetSwipeEdge(offsetWidth: interactiveOffsetWidth)

        withAnimation(.snappy(duration: 0.24, extraBounce: 0.25)) {
            if let targetEdge {
                model.swipe(targetEdge)
            } else {
                model.unswipe()
            }

            interactiveOffsetWidth = model.swipeOffset.width
            model.isSwiping = false
        }

        model.isScrolling = false
        updateSwipeLock(false)
        resetGestureTracking(keepingInteractiveOffset: true)
    }

    private func lockGestureAxisIfNeeded(translation: CGSize, velocity: CGSize) -> Bool {
        if gestureAxis != nil {
            return true
        }

        let lock = model.directionLock
        let absX = abs(translation.width)
        let absY = abs(translation.height)

        if absX < lock.minimumDistance && absY < lock.minimumDistance {
            return false
        }

        if absX >= lock.minimumDistance && absX > absY * lock.horizontalDominance {
            gestureAxis = .horizontal
            gestureStartOffsetWidth = model.swipeOffset.width
            interactiveOffsetWidth = gestureStartOffsetWidth
            updateSwipeLock(true, delayed: false)
            return true
        }

        if model.scrollBehavior.decider(model, translation, velocity)
            || (absY >= lock.minimumDistance && absY > absX * lock.verticalDominance) {
            gestureAxis = .vertical
            model.isScrolling = true

            if model.isSwiped {
                withAnimation(.bouncy) {
                    model.unswipe()
                }
            }

            return false
        }

        return false
    }

    private func canStartSwipe(edge: SwipySwipeEdge, translation: CGSize, velocity: CGSize) -> Bool {
        if model.isSwiped {
            return true
        }

        let swipeTranslation = normalizedGestureValue(translation, for: edge)
        let swipeVelocity = normalizedGestureValue(velocity, for: edge)
        return model.swipeBehavior.decider(model, swipeTranslation, swipeVelocity)
    }

    private func normalizedGestureValue(_ value: CGSize, for edge: SwipySwipeEdge) -> CGSize {
        switch edge {
        case .leading:
            return CGSize(width: -value.width, height: value.height)
        case .trailing:
            return value
        }
    }

    private func canSwipe(_ edge: SwipySwipeEdge) -> Bool {
        model.revealWidth(for: edge) > 0
    }

    private func shouldCollapseAndSuppressRepeatedSwipe(edge: SwipySwipeEdge) -> Bool {
        model.repeatedSwipeBehavior == .collapseAndSuppressUntilEnd
            && model.swipedEdge == edge
            && model.isSwiped
    }

    private func collapseAndSuppressCurrentGesture() {
        isCurrentGestureSuppressed = true

        withAnimation(.bouncy) {
            model.unswipe()
            interactiveOffsetWidth = .zero
            model.isSwiping = false
        }
        updateSwipeLock(false)
    }

    private func clampedOffset(_ offsetWidth: Double) -> Double {
        let leadingRevealWidth = model.revealWidth(for: .leading)
        let trailingRevealWidth = model.revealWidth(for: .trailing)

        return min(max(offsetWidth, -trailingRevealWidth), leadingRevealWidth)
    }

    private func targetSwipeEdge(offsetWidth: Double) -> SwipySwipeEdge? {
        if offsetWidth > 0,
           canSwipe(.leading),
           offsetWidth >= targetThreshold(for: .leading) {
            return .leading
        }

        if offsetWidth < 0,
           canSwipe(.trailing),
           abs(offsetWidth) >= targetThreshold(for: .trailing) {
            return .trailing
        }

        return nil
    }

    private func targetThreshold(for edge: SwipySwipeEdge) -> Double {
        if model.isSwiped, model.swipedEdge == edge {
            return model.closeThreshold(for: edge)
        }

        return model.swipeThreshold(for: edge)
    }

    private func syncSwipedOffsetIfNeeded() {
        guard let swipedEdge = model.swipedEdge, !model.isSwiping else {
            return
        }

        model.swipeOffset.width = model.swipedOffset(for: swipedEdge)
    }

    private func resetGestureTracking(keepingInteractiveOffset: Bool = false) {
        if !keepingInteractiveOffset {
            interactiveOffsetWidth = model.swipeOffset.width
        }

        gestureStartOffsetWidth = model.swipeOffset.width
        gestureAxis = nil
        activeSwipeEdge = nil
        isCurrentGestureSuppressed = false
    }

    public init(isSwipingAnItem: Binding<Bool> = .constant(false),
                swipeActionsMargin: SwipyHorizontalMargin = SwipyDefaults.swipeActionsMargin,
                swipeThreshold: @escaping @MainActor @Sendable (SwipyModel) -> Double = SwipyDefaults.swipeThreshold,
                leadingSwipeThreshold: @escaping @MainActor @Sendable (SwipyModel) -> Double = SwipyDefaults.leadingSwipeThreshold,
                swipeCloseThreshold: @escaping @MainActor @Sendable (SwipyModel, SwipySwipeEdge) -> Double = SwipyDefaults.swipeCloseThreshold,
                swipeBehavior: SwipySwipeBehavior = SwipyDefaults.swipeBehavior,
                scrollBehavior: SwipyScrollBehavior = SwipyDefaults.scrollBehavior,
                repeatedSwipeBehavior: SwipyRepeatedSwipeBehavior = SwipyDefaults.repeatedSwipeBehavior,
                directionLock: SwipyDirectionLock = SwipyDefaults.directionLock,
                actionHeight: SwipyActionHeight = SwipyDefaults.actionHeight,
                @ViewBuilder content: @escaping (SwipyModel) -> C,
                @ViewBuilder actions: @escaping () -> A = SwipyDefaults.swipeActions) {
        self.content = content
        self.leadingActions = { AnyView(EmptyView()) }
        self.actions = actions
        self.actionHeight = actionHeight
        _isSwipingAnItem = isSwipingAnItem

        let model = SwipyModel()
        model.swipeActionsMargin = swipeActionsMargin
        model.swipeThreshold = swipeThreshold
        model.leadingSwipeThreshold = leadingSwipeThreshold
        model.swipeCloseThreshold = swipeCloseThreshold
        model.swipeBehavior = swipeBehavior
        model.scrollBehavior = scrollBehavior
        model.repeatedSwipeBehavior = repeatedSwipeBehavior
        model.directionLock = directionLock
        _model = StateObject(wrappedValue: model)
    }

    public init<LA>(isSwipingAnItem: Binding<Bool> = .constant(false),
                    swipeActionsMargin: SwipyHorizontalMargin = SwipyDefaults.swipeActionsMargin,
                    swipeThreshold: @escaping @MainActor @Sendable (SwipyModel) -> Double = SwipyDefaults.swipeThreshold,
                    leadingSwipeThreshold: @escaping @MainActor @Sendable (SwipyModel) -> Double = SwipyDefaults.leadingSwipeThreshold,
                    swipeCloseThreshold: @escaping @MainActor @Sendable (SwipyModel, SwipySwipeEdge) -> Double = SwipyDefaults.swipeCloseThreshold,
                    swipeBehavior: SwipySwipeBehavior = SwipyDefaults.swipeBehavior,
                    scrollBehavior: SwipyScrollBehavior = SwipyDefaults.scrollBehavior,
                    repeatedSwipeBehavior: SwipyRepeatedSwipeBehavior = SwipyDefaults.repeatedSwipeBehavior,
                    directionLock: SwipyDirectionLock = SwipyDefaults.directionLock,
                    actionHeight: SwipyActionHeight = SwipyDefaults.actionHeight,
                    @ViewBuilder content: @escaping (SwipyModel) -> C,
                    @ViewBuilder leadingActions: @escaping () -> LA,
                    @ViewBuilder actions: @escaping () -> A) where LA: View {
        self.content = content
        self.leadingActions = { AnyView(leadingActions()) }
        self.actions = actions
        self.actionHeight = actionHeight
        _isSwipingAnItem = isSwipingAnItem

        let model = SwipyModel()
        model.swipeActionsMargin = swipeActionsMargin
        model.swipeThreshold = swipeThreshold
        model.leadingSwipeThreshold = leadingSwipeThreshold
        model.swipeCloseThreshold = swipeCloseThreshold
        model.swipeBehavior = swipeBehavior
        model.scrollBehavior = scrollBehavior
        model.repeatedSwipeBehavior = repeatedSwipeBehavior
        model.directionLock = directionLock
        _model = StateObject(wrappedValue: model)
    }
}

private enum SwipyGestureAxis {
    case horizontal
    case vertical
}

private struct SwipySizeReader: View {
    let onChange: @MainActor (CGSize) -> Void

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    onChange(geometry.size)
                }
                .onChange(of: geometry.size) { newValue in
                    onChange(newValue)
                }
        }
    }
}

public struct SwipyAction<C>: View where C: View {
    @EnvironmentObject public var model: SwipyModel
    @Environment(\.swipyActionStyle) private var actionStyle
    
    public let content: (SwipyModel) -> C

    public var body: some View {
        VStack {
            content(model)
        }
        .modifier(SwipyActionStyleModifier(style: actionStyle))
    }

    public init(@ViewBuilder content: @escaping (SwipyModel) -> C) {
        self.content = content
    }
}

private struct SwipyActionStyleModifier: ViewModifier {
    let style: SwipyActionStyle

    func body(content: Content) -> some View {
        let styled = content.frame(height: style.height)

        if let cornerRadius = style.cornerRadius {
            styled.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            styled
        }
    }
}

@available(iOS 18.0, * )
struct SimultaneousSwipeGesture: UIGestureRecognizerRepresentable {
    
    let onBegan: (UILongPressGestureRecognizer) -> Void
    let onChanged: (UILongPressGestureRecognizer, CGSize, CGSize) -> Void
    let onEnded: (UILongPressGestureRecognizer, CGSize, CGSize) -> Void

    init(
        onBegan: @escaping (UILongPressGestureRecognizer) -> Void = { _ in },
        onChanged: @escaping (UILongPressGestureRecognizer, CGSize, CGSize) -> Void = { _, _, _ in },
        onEnded: @escaping (UILongPressGestureRecognizer, CGSize, CGSize) -> Void = { _, _, _ in }
    ) {
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
    }
    
    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let gestureRecognizer = UILongPressGestureRecognizer()
        gestureRecognizer.minimumPressDuration = 0.0
        gestureRecognizer.allowableMovement = CGFloat.greatestFiniteMagnitude
        gestureRecognizer.delegate = context.coordinator
        return gestureRecognizer
    }
    
    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let currentTime = Date()
        let location = recognizer.location(in: recognizer.view)
        
        switch recognizer.state {
        case .began:
            context.coordinator.startLocation = location
            context.coordinator.startTime = currentTime
            context.coordinator.lastLocation = location
            context.coordinator.lastTime = currentTime
            onBegan(recognizer)
        
        case .changed:
            let translation = CGSize(
                width: location.x - context.coordinator.startLocation.x,
                height: location.y - context.coordinator.startLocation.y
            )
            let velocity = context.coordinator.getVelocity(currentLocation: location, currentTime: currentTime)
            onChanged(recognizer, translation, velocity)
            
            context.coordinator.lastLocation = location
            context.coordinator.lastTime = currentTime
        
        case .ended, .cancelled:
            let translation = CGSize(
                width: location.x - context.coordinator.startLocation.x,
                height: location.y - context.coordinator.startLocation.y
            )
            let velocity = context.coordinator.getVelocity(currentLocation: location, currentTime: currentTime)
            onEnded(recognizer, translation, velocity)
            
            context.coordinator.startLocation = .zero
            context.coordinator.startTime = Date()
            context.coordinator.lastLocation = .zero
            context.coordinator.lastTime = Date()
        
        default:
            break
        }
    }
    
    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {}
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var startLocation: CGPoint = .zero
        var startTime: Date = Date()
        var lastLocation: CGPoint = .zero
        var lastTime: Date = Date()
        
        func getVelocity(currentLocation: CGPoint, currentTime: Date) -> CGSize {
            let timeDelta = currentTime.timeIntervalSince(lastTime)
            guard timeDelta > 0 else {
                return .zero
            }
            
            let deltaX = currentLocation.x - lastLocation.x
            let deltaY = currentLocation.y - lastLocation.y
            
            return CGSize(
                width: deltaX / timeDelta,
                height: deltaY / timeDelta
            )
        }
        
        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }
    }
}

extension View {
    @ViewBuilder
    func modifier(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        } else {
            self
        }
    }
}

struct Preview: View {
    @State var isSwipingAnItem = false
    
    @State var items: [String] = [
        "Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6", "Item 7", "Item 8", "Item 9", "Item 10", "Item 11", "Item 12", "Item 13", "Item 14", "Item 15", "Item 16", "Item 17", "Item 18", "Item 19", "Item 20"
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.9), .cyan.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 50)
            .hueRotation(.degrees(isSwipingAnItem ? 45 : 0))
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isSwipingAnItem)
            .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(items, id: \.self) { item in
                        Swipy(isSwipingAnItem: $isSwipingAnItem, swipeActionsMargin: .init(leading: 0, trailing: 20)) { model in
                            HStack(spacing: 10) {
                                Button {
                                    withAnimation(.bouncy) {
                                        model.swipe()
                                    }
                                } label: {
                                    VStack {
                                        Image(systemName: "trash")
                                            .font(.system(size: 20))
                                    }
                                    .padding()
                                    .background(.thinMaterial)
                                    .cornerRadius(16)
                                    .foregroundColor(.black)
                                }
                                Text(item)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.thinMaterial)
                                    .cornerRadius(16)
                                    .foregroundColor(.black)
                            }
                            .padding(.horizontal)
                        } leadingActions: {
                            SwipyAction { model in
                                Button {
                                    withAnimation(.bouncy) {
                                        if let index = items.firstIndex(of: item) {
                                            let pinnedItem = items.remove(at: index)
                                            items.insert(pinnedItem, at: 0)
                                        }

                                        model.unswipe()
                                    }
                                } label: {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 20))
                                }
                                .frame(maxHeight: .infinity)
                                .padding(.horizontal)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            .linearGradient(
                                                colors: [.orange.opacity(0.8), .yellow.opacity(0.8)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                )
                                .foregroundColor(.white)
                            }
                        } actions: {
                            HStack {
                                SwipyAction { model in
                                    Button {
                                        withAnimation(.bouncy) {
                                            items.removeAll { $0 == item }
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 20))
                                    }
                                    .frame(maxHeight: .infinity)
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                .linearGradient(
                                                    colors: [.pink.opacity(0.8), .red.opacity(0.8)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    )
                                    .foregroundColor(.white)
                                }
                                SwipyAction { model in
                                    Button {
                                        withAnimation(.bouncy) {
                                            model.unswipe()
                                        }
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 20))
                                    }
                                    .frame(maxHeight: .infinity)
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                .linearGradient(
                                                    colors: [.mint.opacity(0.8), .blue.opacity(0.8)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    )
                                    .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    Preview()
}
