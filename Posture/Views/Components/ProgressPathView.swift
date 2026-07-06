import SwiftUI

struct ProgressPathView: View {
    let currentLevel: Int
    let maxLevel: Int
    let isPro: Bool
    var windowRadius: Int = 2
    var onLockedTap: (() -> Void)? = nil

    private var visibleLevels: [Int] {
        let low = max(1, currentLevel - windowRadius)
        let high = min(maxLevel, currentLevel + windowRadius)
        return Array(low...high)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(visibleLevels.enumerated()), id: \.element) { index, level in
                        if index > 0 {
                            connector(filled: level <= currentLevel)
                        }
                        node(level: level).id(level)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .onAppear { proxy.scrollTo(currentLevel, anchor: .center) }
            .onChange(of: currentLevel) { _, level in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(level, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func node(level: Int) -> some View {
        let isCurrent = level == currentLevel
        let isPast = level < currentLevel
        let locked = !isPro && level > PracticeProgression.freeLevelCap

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Theme.sage : (isPast ? Theme.sageTint : Theme.paper3))
                    .frame(width: isCurrent ? 36 : 30, height: isCurrent ? 36 : 30)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                } else if isPast {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.sage)
                } else {
                    Text("\(level)")
                        .font(Theme.font(.caption2, weight: .bold))
                        .foregroundStyle(isCurrent ? .white : Theme.ink3)
                }
            }
            Text("L\(level)")
                .font(Theme.font(.caption2, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? Theme.sage : Theme.ink3)
        }
        .frame(minWidth: 44)
        .onTapGesture { if locked { onLockedTap?() } }
    }

    private func connector(filled: Bool) -> some View {
        Rectangle()
            .fill(filled ? Theme.sage.opacity(0.45) : Theme.paper3)
            .frame(width: 20, height: 2)
            .padding(.bottom, 18)
    }
}

struct ProgramStageCompareView: View {
    let currentLevel: Int
    let nextLevel: Int

    var body: some View {
        HStack(spacing: 0) {
            stageColumn(label: "NOW", level: currentLevel, emphasized: true)
            Rectangle().fill(Theme.paper3).frame(width: 1)
            stageColumn(label: "NEXT", level: nextLevel, emphasized: false)
        }
        .dawnCard(cornerRadius: 14)
    }

    private func stageColumn(label: String, level: Int, emphasized: Bool) -> some View {
        let minutes = PracticeProgression.sessionSeconds(forLevel: level) / 60
        let target = PracticeProgression.targetPercent(forLevel: level)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.font(.caption2, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(emphasized ? Theme.sage : Theme.ink3)
            Text("Level \(level)")
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink3)
            Text("\(minutes) min")
                .font(Theme.font(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(target)% aligned")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(emphasized ? Theme.sageTint.opacity(0.35) : Color.clear)
    }
}
