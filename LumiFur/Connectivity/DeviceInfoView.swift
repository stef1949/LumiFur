//
//  DeviceInfoView.swift
//  LumiFur
//
//  Created by Stephan Ritchie on 6/7/25.
//
import SwiftUI

struct DeviceInfoView: View {
    @ObservedObject var accessoryViewModel: AccessoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let info = accessoryViewModel.deviceInfo {
                infoGrid(info)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                loading
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        )
        .animation(.easeInOut(duration: 0.25), value: accessoryViewModel.deviceInfo?.id)
        .frame(maxWidth: 320, alignment: .leading)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
            Text("Device Info")
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var loading: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Reading device info…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func infoGrid(_ info: DeviceInfo) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 8) {

            row("Model", info.model)

            row("Firmware", info.fw)

            // Commit + copy
            GridRow {
                label("Commit")
                HStack(spacing: 8) {
                    value(info.commit, monospaced: true)
                    copyButton(info.commit)
                }
            }

            row("Branch", info.branch)

            row("Build", info.build)

            row("Compat", "\(info.compat)+")

            // ID + copy
            GridRow {
                label("ID")
                HStack(spacing: 8) {
                    value(info.id, monospaced: true)
                    copyButton(info.id)
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle) // helps for long IDs/commits
    }

    private func row(_ title: String, _ val: String) -> some View {
        GridRow {
            label(title)
            value(val)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(minWidth: 70, alignment: .leading)
    }

    private func value(_ text: String, monospaced: Bool = false) -> some View {
        let t = Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)

        return Group {
            if monospaced {
                t.monospaced()
            } else {
                t
            }
        }
        .foregroundStyle(.primary.opacity(0.85))
    }

    @ViewBuilder
    private func copyButton(_ text: String) -> some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = text
            #endif
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Copy")
    }
}
