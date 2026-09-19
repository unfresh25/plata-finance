import SwiftUI

// Cuestionario de onboarding tras la intro cinemática y antes de crear la cuenta.
// Cuatro preguntas paso a paso sobre el fondo violeta (estilo Fuse). Las
// respuestas se guardan localmente (OnboardingSurveyStore) y se suben al perfil
// después de registrarse. Al terminar, onFinish() lleva a autenticación.

struct OnboardingQuestionsView: View {
    var onFinish: () -> Void

    @State private var step = 0
    @State private var survey = OnboardingSurvey()

    private let steps = OnboardingStep.all

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Space.xl) {
                // Barra de progreso + volver.
                header

                let s = steps[step]

                VStack(alignment: .leading, spacing: Space.s) {
                    Text(s.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let sub = s.subtitle {
                        Text(sub)
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                .id("q\(step)")
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                // Opciones.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.m) {
                        ForEach(s.options, id: \.self) { option in
                            OnboardingOptionRow(
                                text: option,
                                selected: isSelected(option),
                                multi: s.multi
                            ) {
                                toggle(option)
                            }
                        }
                    }
                    .id("opts\(step)")
                    .transition(.opacity)
                }

                Spacer(minLength: 0)

                // Continuar.
                PrimaryButton(title: step == steps.count - 1 ? "Listo" : "Continuar") {
                    next()
                }
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.5)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.xl)
            .animation(Motion.ui, value: step)
        }
    }

    // MARK: - Header (progreso)

    private var header: some View {
        HStack(spacing: Space.m) {
            if step > 0 {
                Button {
                    withAnimation(Motion.ui) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            // Barra de progreso segmentada.
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Palette.accent : Palette.stroke)
                        .frame(height: 4)
                }
            }
            Button("Saltar", action: onFinish)
                .font(Typo.caption)
                .foregroundStyle(Palette.inkTertiary)
        }
    }

    // MARK: - Lógica

    private func isSelected(_ option: String) -> Bool {
        switch step {
        case 0: return survey.manejo == option
        case 1: return survey.reto == option
        case 2: return survey.objetivos.contains(option)
        case 3: return survey.pareja == option
        default: return false
        }
    }

    private func toggle(_ option: String) {
        switch step {
        case 0: survey.manejo = option
        case 1: survey.reto = option
        case 2:
            if let i = survey.objetivos.firstIndex(of: option) { survey.objetivos.remove(at: i) }
            else { survey.objetivos.append(option) }
        case 3: survey.pareja = option
        default: break
        }
        // Selección simple avanza sola tras un instante; multi espera "Continuar".
        if !steps[step].multi {
            Task {
                try? await Task.sleep(for: .seconds(0.28))
                next()
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: return survey.manejo != nil
        case 1: return survey.reto != nil
        case 2: return !survey.objetivos.isEmpty
        case 3: return survey.pareja != nil
        default: return true
        }
    }

    private func next() {
        guard canContinue else { return }
        if step < steps.count - 1 {
            withAnimation(Motion.ui) { step += 1 }
        } else {
            OnboardingSurveyStore.savePending(survey)
            onFinish()
        }
    }
}

// MARK: - Definición de pasos

private struct OnboardingStep {
    let title: String
    let subtitle: String?
    let options: [String]
    var multi: Bool = false

    static let all: [OnboardingStep] = [
        .init(title: "¿Cómo llevan la plata hoy?",
              subtitle: "Sin juzgar. Es para arrancar bien.",
              options: ["Cada uno por su lado", "Todo revuelto en una cuenta", "Con una app o Excel", "La verdad, ni idea"]),
        .init(title: "¿Qué es lo que más los enreda?",
              subtitle: nil,
              options: ["Saber en qué se va", "Ponernos de acuerdo", "Ahorrar para algo", "Las deudas"]),
        .init(title: "¿Para qué quieren usar Plata?",
              subtitle: "Elige las que quieras.",
              options: ["Ver los gastos", "Dividir cuentas", "Ahorrar juntos", "Controlar deudas", "Seguir suscripciones"],
              multi: true),
        .init(title: "¿Están los dos aquí?",
              subtitle: nil,
              options: ["Sí, invito a mi pareja ya", "Yo primero, luego la invito"]),
    ]
}

// MARK: - Fila de opción

private struct OnboardingOptionRow: View {
    let text: String
    let selected: Bool
    let multi: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Text(text)
                    .font(Typo.callout)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Space.s)
                Image(systemName: selected ? (multi ? "checkmark.square.fill" : "checkmark.circle.fill")
                                           : (multi ? "square" : "circle"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Palette.accent : Palette.inkTertiary)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : Palette.stroke, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .pressable(scale: 0.98)
    }
}
