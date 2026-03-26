import Foundation

protocol CalculatorsServiceProtocol {
    func fetchCatalog() async throws -> [CalculatorCatalogItem]
    func fetchDefinition(calculatorId: String) async throws -> CalculatorDefinition
    func calculate(
        calculatorId: String,
        inputs: [String: CalculatorInputValue],
        profileId: String?
    ) async throws -> CalculatorCalculateResult
}

enum CalculatorInputValue: Equatable {
    case number(Double)
    case string(String)
}

extension CalculatorInputValue: Encodable {
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .number(let v):
            try c.encode(v)
        case .string(let s):
            try c.encode(s)
        }
    }
}

struct CalculatorCatalogItem: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let order: Int
    let isEnabled: Bool
    let version: Int
}

struct CalculatorDefinition: Equatable {
    let calculatorId: String
    let title: String
    let description: String
    let helpText: String?

    let uiGroups: [CalculatorUIGroupsSection]
    let inputs: [CalculatorInput]
    let conditionalRules: [CalculatorConditionalRule]
    let outputs: [CalculatorOutput]
    let interpretation: CalculatorInterpretation?
    let flow: CalculatorFlow?
}

enum CalculatorFlowMode: String, Equatable, Codable {
    case single
    case multistep

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self).lowercased()
        switch raw {
        case "single", "one_step", "one-step":
            self = .single
        case "multistep", "multi_step", "multi-step":
            self = .multistep
        default:
            self = .single
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

struct CalculatorFlowStep: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let inputKeys: [String]
    let nextButtonTitle: String?
}

struct CalculatorFlow: Equatable {
    let mode: CalculatorFlowMode
    let steps: [CalculatorFlowStep]
}

struct CalculatorUIGroupsSection: Equatable {
    let title: String
    let inputKeys: [String]
}

enum CalculatorInputType: String, Equatable, Codable {
    case number
    case select
}

struct CalculatorInputOption: Equatable {
    let value: String
    let label: String
}

struct CalculatorInput: Equatable, Identifiable {
    var id: String { key }

    let key: String
    let type: CalculatorInputType
    let title: String
    let unit: String?
    let required: Bool

    // number
    let min: Double?
    let max: Double?
    let step: Double?

    // select
    let options: [CalculatorInputOption]
    let placeholder: String?
    let defaultValue: CalculatorInputDefaultValue?
}

enum CalculatorInputDefaultValue: Equatable {
    case number(Double)
    case string(String)
}

struct CalculatorConditionalIf: Equatable {
    let inputKey: String
    let equals: String?
    let notEquals: String?
}

struct CalculatorConditionalRule: Equatable {
    let ifRule: CalculatorConditionalIf
    let showInputKeys: [String]
}

struct CalculatorOutput: Equatable, Identifiable {
    var id: String { key }

    let key: String
    let title: String
    let unit: String?
    let decimals: Int?
    /// Backend-provided formula/expression (definition.outputs[].expression.value).
    /// iOS uses it only for displaying "Как считается" (we don't evaluate it on device).
    let expressionValue: String?
}

struct CalculatorInterpretationRange: Equatable {
    let min: Double?
    let max: Double?
    let label: String
    let subtitle: String?
}

struct CalculatorInterpretation: Equatable {
    let targetOutputKey: String
    let ranges: [CalculatorInterpretationRange]
}

struct CalculatorCalculateResult: Equatable {
    let calculatorId: String
    let outputs: [String: Double]
    let interpretationLabel: String?
    let interpretationSubtitle: String?
    let summary: String?
    let resultDescriptions: [CalculatorResultTextItem]
    let recommendations: [CalculatorResultTextItem]
}

struct CalculatorResultTextItem: Equatable, Decodable {
    let title: String
    let description: String
}

// MARK: - Backend DTOs

extension CalculatorCatalogItem {
    struct DTO: Decodable {
        let id: String
        let title: String
        let description: String
        let order: Int
        let isEnabled: Bool
        let version: Int
    }
}

extension CalculatorDefinition {
    struct DTO: Decodable {
        let calculatorId: String
        let title: String
        let description: String
        let helpText: String?
        let ui: DTOUI
        let inputs: [DTOInput]
        let conditional: [DTOConditionalRule]?
        let outputs: [DTOOutput]
        let interpretation: DTOInterpretation?
        let flow: DTOFlow?

        struct DTOUI: Decodable {
            let groups: [DTOTitleGroup]
        }

        struct DTOTitleGroup: Decodable {
            let title: String
            let inputKeys: [String]
        }

        struct DTOInput: Decodable {
            let key: String
            let type: CalculatorInputType
            let title: String
            let unit: String?
            let required: Bool
            let min: Double?
            let max: Double?
            let step: Double?
            let options: [DTOOption]?
            let placeholder: String?
            let defaultValue: DTODefaultValue?

            struct DTOOption: Decodable {
                let value: String
                let label: String
            }

            enum DTODefaultValue: Equatable {
                case number(Double)
                case string(String)
            }

            enum CodingKeys: String, CodingKey {
                case key, type, title, unit, required, min, max, step, options, placeholder, defaultValue
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                key = try c.decode(String.self, forKey: .key)
                type = try c.decode(CalculatorInputType.self, forKey: .type)
                title = try c.decode(String.self, forKey: .title)
                unit = try c.decodeIfPresent(String.self, forKey: .unit)
                required = try c.decode(Bool.self, forKey: .required)
                min = try c.decodeIfPresent(Double.self, forKey: .min)
                max = try c.decodeIfPresent(Double.self, forKey: .max)
                step = try c.decodeIfPresent(Double.self, forKey: .step)
                options = try c.decodeIfPresent([DTOOption].self, forKey: .options)
                placeholder = try c.decodeIfPresent(String.self, forKey: .placeholder)

                if let value = try c.decodeIfPresent(Double.self, forKey: .defaultValue) {
                    defaultValue = .number(value)
                } else if let str = try c.decodeIfPresent(String.self, forKey: .defaultValue) {
                    defaultValue = .string(str)
                } else {
                    defaultValue = nil
                }
            }
        }

        struct DTOConditionalRule: Decodable {
            let `if`: DTOIf
            let showInputKeys: [String]

            struct DTOIf: Decodable {
                let inputKey: String
                let equals: String?
                let notEquals: String?
            }
        }

        struct DTOOutput: Decodable {
            let key: String
            let title: String
            let unit: String?
            let decimals: Int?
            // expression is ignored by iOS; backend uses it to calculate.
            let expression: DTOExpression?

            struct DTOExpression: Decodable {
                let type: String?
                let value: String?
            }
        }

        struct DTOInterpretation: Decodable {
            let targetOutputKey: String
            let ranges: [DTORange]

            struct DTORange: Decodable {
                let min: Double?
                let max: Double?
                let label: String
                let subtitle: String?
            }
        }

        struct DTOFlow: Decodable {
            let mode: CalculatorFlowMode
            let steps: [DTOStep]

            struct DTOStep: Decodable {
                let id: String
                let title: String
                let subtitle: String?
                let inputKeys: [String]
                let nextButtonTitle: String?
            }

            enum CodingKeys: String, CodingKey {
                case mode
                case steps
                case levels
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                mode = (try? container.decode(CalculatorFlowMode.self, forKey: .mode)) ?? .single
                if let decoded = try? container.decode([DTOStep].self, forKey: .steps) {
                    steps = decoded
                } else {
                    steps = (try? container.decode([DTOStep].self, forKey: .levels)) ?? []
                }
            }
        }
    }
}

extension CalculatorCalculateResult {
    struct DTO: Decodable {
        let calculatorId: String
        let outputs: [String: Double]
        let interpretation: InterpretationDTO?
        let summary: String?
        let resultDescriptions: [CalculatorResultTextItem]?
        let recommendations: [CalculatorResultTextItem]?

        struct InterpretationDTO: Decodable {
            let label: String?
            let subtitle: String?
        }
    }
}

