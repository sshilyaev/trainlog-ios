import Foundation

final class APICalculatorsService: CalculatorsServiceProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    convenience init(baseURL: URL, getIDToken: @escaping (_ forceRefresh: Bool) async -> String?) {
        self.init(client: APIClient(baseURL: baseURL, getIDToken: getIDToken))
    }

    func fetchCatalog() async throws -> [CalculatorCatalogItem] {
        struct Response: Decodable {
            let calculators: [CalculatorCatalogItem.DTO]
        }
        let res: Response = try await client.request(path: "api/v1/calculators/catalog", useDateTimeDecoder: true)
        return res.calculators.map { dto in
            CalculatorCatalogItem(
                id: dto.id,
                title: dto.title,
                description: dto.description,
                order: dto.order,
                isEnabled: dto.isEnabled,
                version: dto.version
            )
        }
    }

    func fetchDefinition(calculatorId: String) async throws -> CalculatorDefinition {
        struct Response: Decodable {
            let definition: CalculatorDefinition.DTO
        }
        let res: Response = try await client.request(path: "api/v1/calculators/\(calculatorId)/definition", useDateTimeDecoder: true)
        return map(res.definition)
    }

    func calculate(
        calculatorId: String,
        inputs: [String: CalculatorInputValue],
        profileId: String?
    ) async throws -> CalculatorCalculateResult {
        struct Request: Encodable {
            let profileId: String?
            let inputs: [String: CalculatorInputValue]
        }

        struct Response: Decodable {
            let calculatorId: String
            let outputs: [String: Double]
            let interpretation: CalculatorCalculateResult.DTO.InterpretationDTO?
            let summary: String?
            let resultDescriptions: [CalculatorResultTextItem]?
            let recommendations: [CalculatorResultTextItem]?
        }

        let body = Request(profileId: profileId, inputs: inputs)
        let res: Response = try await client.request(
            path: "api/v1/calculators/\(calculatorId)/calculate",
            method: "POST",
            body: body,
            useDateTimeDecoder: true
        )

        return CalculatorCalculateResult(
            calculatorId: res.calculatorId,
            outputs: res.outputs,
            interpretationLabel: res.interpretation?.label,
            interpretationSubtitle: res.interpretation?.subtitle,
            summary: res.summary,
            resultDescriptions: res.resultDescriptions ?? [],
            recommendations: res.recommendations ?? []
        )
    }
}

private extension APICalculatorsService {
    func map(_ dto: CalculatorDefinition.DTO) -> CalculatorDefinition {
        let uiGroups = dto.ui.groups.map { g in
            CalculatorUIGroupsSection(title: g.title, inputKeys: g.inputKeys)
        }

        let inputs = dto.inputs.map { i -> CalculatorInput in
            let type = i.type
            let options = (i.options ?? []).map { opt in
                CalculatorInputOption(value: opt.value, label: opt.label)
            }
            return CalculatorInput(
                key: i.key,
                type: type,
                title: i.title,
                unit: i.unit,
                required: i.required,
                min: i.min,
                max: i.max,
                step: i.step,
                options: options,
                placeholder: i.placeholder,
                defaultValue: mapDefaultValue(i.defaultValue)
            )
        }

        let conditionalRules = (dto.conditional ?? []).map { r -> CalculatorConditionalRule in
            CalculatorConditionalRule(
                ifRule: CalculatorConditionalIf(
                    inputKey: r.if.inputKey,
                    equals: r.if.equals,
                    notEquals: r.if.notEquals
                ),
                showInputKeys: r.showInputKeys
            )
        }

        let outputs = dto.outputs.map { o in
            CalculatorOutput(
                key: o.key,
                title: o.title,
                unit: o.unit,
                decimals: o.decimals,
                expressionValue: o.expression?.value
            )
        }

        let interpretation = dto.interpretation.map { interp in
            CalculatorInterpretation(
                targetOutputKey: interp.targetOutputKey,
                ranges: interp.ranges.map { r in
                    CalculatorInterpretationRange(
                        min: r.min,
                        max: r.max,
                        label: r.label,
                        subtitle: r.subtitle
                    )
                }
            )
        }

        let flow = dto.flow.map { f in
            CalculatorFlow(
                mode: f.mode,
                steps: f.steps.map { step in
                    CalculatorFlowStep(
                        id: step.id,
                        title: step.title,
                        subtitle: step.subtitle,
                        inputKeys: step.inputKeys,
                        nextButtonTitle: step.nextButtonTitle
                    )
                }
            )
        }

        return CalculatorDefinition(
            calculatorId: dto.calculatorId,
            title: dto.title,
            description: dto.description,
            helpText: dto.helpText,
            uiGroups: uiGroups,
            inputs: inputs,
            conditionalRules: conditionalRules,
            outputs: outputs,
            interpretation: interpretation,
            flow: flow
        )
    }

    func mapDefaultValue(_ dto: CalculatorDefinition.DTO.DTOInput.DTODefaultValue?) -> CalculatorInputDefaultValue? {
        guard let dto else { return nil }
        switch dto {
        case .number(let n): return .number(n)
        case .string(let s): return .string(s)
        }
    }
}

