//
//  ProgressAddFormToolbarPreference.swift
//  Состояние кнопки «Сохранить» для шита «Замер / цель»: читается хостом, выставляется формой.
//

import SwiftUI
import UIKit

struct ProgressAddFormToolbarState: Equatable {
    var canSave: Bool
    var isLoading: Bool
}

struct ProgressAddFormToolbarPreferenceKey: PreferenceKey {
    static var defaultValue: ProgressAddFormToolbarState {
        ProgressAddFormToolbarState(canSave: false, isLoading: false)
    }

    static func reduce(value: inout ProgressAddFormToolbarState, nextValue: () -> ProgressAddFormToolbarState) {
        value = nextValue()
    }
}

/// Навигация для форм замера/цели: самостоятельный шит или вложенность в `AddMeasurementOrGoalSheet`.
struct ProgressAddFormNavigationChrome: ViewModifier {
    let useHostChrome: Bool
    var hostSavePulse: Binding<Int>
    let navigationTitle: String
    let hasAnyValue: Bool
    let isLoading: Bool
    let onCancel: () -> Void
    let onSaveTap: () -> Void

    func body(content: Content) -> some View {
        Group {
            if useHostChrome {
                content
                    .onChange(of: hostSavePulse.wrappedValue) { _, _ in
                        onSaveTap()
                    }
                    .preference(
                        key: ProgressAddFormToolbarPreferenceKey.self,
                        value: ProgressAddFormToolbarState(canSave: hasAnyValue, isLoading: isLoading)
                    )
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Готово") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .fontWeight(.regular)
                        }
                    }
            } else {
                content
                    .navigationTitle(navigationTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            BackToolbarButton(action: onCancel)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: onSaveTap) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                } else {
                                    Text("Сохранить")
                                        .font(.body)
                                        .fontWeight(.regular)
                                }
                            }
                            .disabled(!hasAnyValue || isLoading)
                        }
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Готово") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .fontWeight(.regular)
                        }
                    }
            }
        }
    }
}
