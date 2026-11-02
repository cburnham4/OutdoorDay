//
//  ContentView.swift
//  Outdoor Day
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: DayPlannerModel
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var showPaywall = false

    private static var skipAdsForScreenshots: Bool {
        UserDefaults.standard.bool(forKey: "skipATT")
            || ProcessInfo.processInfo.arguments.contains("-skipATT")
            || ProcessInfo.processInfo.environment["SKIP_ATT"] == "1"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.96, blue: 0.98),
                        Color(red: 0.86, green: 0.92, blue: 0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        verdictCard
                        metricsRow
                        if purchases.isPremium {
                            premiumOutlookCard
                        } else {
                            upgradeCard
                        }
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, purchases.isPremium ? 24 : 72)
                }
                .refreshable { await model.refresh() }
            }
            .safeAreaInset(edge: .bottom) {
                if !purchases.isPremium && !Self.skipAdsForScreenshots {
                    AdBannerView()
                        .frame(height: 50)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Outdoor Day")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isLoading)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(purchases)
            }
            .task {
                model.start()
                await model.refresh()
            }
            .onReceive(model.location.$coordinate) { coordinate in
                guard coordinate != nil else { return }
                Task { await model.onLocationMaybeUpdated() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Should I go outside?")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Color(red: 0.12, green: 0.22, blue: 0.28))
            Text(model.placeName ?? "Using your current location")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var verdictCard: some View {
        if model.isLoading && model.conditions == nil {
            ProgressView("Checking UV, pollen & air…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let conditions = model.conditions {
            let verdict = conditions.verdict
            VStack(spacing: 14) {
                Image(systemName: verdict.symbolName)
                    .font(.system(size: 44))
                    .foregroundStyle(verdict.tint)
                Text(verdict.rawValue)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(verdict.tint)
                Text(verdict.detail)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.22, green: 0.28, blue: 0.32))
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
        } else if let error = model.errorMessage {
            Text(error)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    private var metricsRow: some View {
        Group {
            if let conditions = model.conditions {
                HStack(spacing: 12) {
                    MetricChip(
                        title: "UV",
                        value: conditions.uvIndex.map { String(format: "%.1f", $0) } ?? "—",
                        band: VerdictEngine.uvBand(conditions.uvIndex)
                    )
                    MetricChip(
                        title: conditions.pollenLabel,
                        value: conditions.pollenGrains.map { String(format: "%.0f", $0) } ?? "N/A",
                        band: VerdictEngine.pollenBand(conditions.pollenGrains),
                        bandOverride: conditions.pollenGrains == nil ? "Unavailable" : nil
                    )
                    MetricChip(
                        title: "AQI",
                        value: conditions.usAqi.map(String.init) ?? "—",
                        band: VerdictEngine.aqiBand(conditions.usAqi)
                    )
                }
            }
        }
    }

    private var upgradeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Go ad-free")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(purchases.product?.displayPrice ?? "$2.99")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("One-time unlock: remove the banner and get a 3-day outdoor outlook.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showPaywall = true
            } label: {
                Text("Unlock Outdoor Day Plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.12, green: 0.45, blue: 0.42))
        }
        .padding(18)
        .background(.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var premiumOutlookCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next few days")
                .font(.headline)
            if model.outlook.isEmpty {
                Text("Pull to refresh for the 3-day outdoor outlook.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.outlook) { day in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.weekdayLabel)
                                .font(.subheadline.weight(.semibold))
                            Text(day.verdict.rawValue)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(day.verdict.tint)
                        }
                        .frame(width: 108, alignment: .leading)
                        Spacer(minLength: 0)
                        outlookMetric(title: "UV", value: day.uvIndexMax.map { String(format: "%.0f", $0) } ?? "—")
                        outlookMetric(title: "AQI", value: day.usAqiMax.map(String.init) ?? "—")
                        outlookMetric(
                            title: "Pollen",
                            value: day.pollenGrains.map { String(format: "%.0f", $0) } ?? "N/A"
                        )
                    }
                    .padding(.vertical, 4)
                    if day.id != model.outlook.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func outlookMetric(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
        }
        .frame(minWidth: 44)
    }

    private var footnote: some View {
        Text("Data from Open-Meteo. Not medical advice — check local alerts if you’re sensitive.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricChip: View {
    let title: String
    let value: String
    let band: RiskBand
    var bandOverride: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text(bandOverride ?? band.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(bandOverride == nil ? band.tint : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Outdoor Day Plus")
                    .font(.largeTitle.bold())
                Text("One-time unlock: no ads, plus a 3-day outdoor outlook from UV, pollen, and air quality.")
                    .foregroundStyle(.secondary)
                if let product = purchases.product {
                    Text(product.displayPrice)
                        .font(.title.weight(.semibold))
                }
                if let err = purchases.purchaseError {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }
                Button {
                    Task {
                        await purchases.purchase()
                        if purchases.isPremium { dismiss() }
                    }
                } label: {
                    Group {
                        if purchases.isPurchasing {
                            ProgressView()
                        } else {
                            Text("Unlock")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(purchases.isPurchasing)

                Button("Restore purchases") {
                    Task { await purchases.restore() }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await purchases.loadProduct() }
        }
    }
}
