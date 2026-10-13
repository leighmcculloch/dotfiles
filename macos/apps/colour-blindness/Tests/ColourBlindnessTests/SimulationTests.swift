import XCTest
@testable import ColourBlindness

final class SimulationTests: XCTestCase {
    // Reference outputs from the published matrices, on asymmetric linear RGB.
    // A transposed matrix, swapped type, or applying a dichromacy matrix to an
    // anomaly produces different results for these colours.
    func testPublishedSimulationOutputs() {
        let cases: [(VisionType, Double, [Double])] = [
            (.protanopia, 0.2, [0.640233, 0.51680075, 0.1300538]),
            (.deuteranopia, 0.8, [0.7450837, 0.6094432, 0.15557315]),
            (.tritanopia, 0.3, [1.0, 0.41305435, 0.39576485]),
            (.protanomaly, 0.5, [0.7543035, 0.52043755, 0.13812235]),
            (.deuteranomaly, 0.5, [0.80071295, 0.5689633, 0.1512184]),
            (.tritanomaly, 0.5, [0.97328175, 0.48057725, 0.242151]),
            (.achromatopsia, 0.1, [0.5704, 0.5704, 0.5704]),
            (.achromatomaly, 0.5, [0.7602, 0.5352, 0.3602])
        ]
        for (type, severity, expected) in cases {
            let matrix = Simulation(type: type, severity: severity).matrix
            let input = [0.95, 0.5, 0.15]
            for row in 0..<3 {
                let output = (0..<3).reduce(0.0) { $0 + matrix[row * 3 + $1] * input[$1] }
                XCTAssertEqual(min(1, max(0, output)), expected[row], accuracy: 0.000001, type.title)
            }
        }
    }

    func testSeverityEndpointsAndInterpolation() {
        let identity = [1.0, 0, 0, 0, 1, 0, 0, 0, 1]
        for type in VisionType.allCases where type.hasSeverity {
            XCTAssertEqual(Simulation(type: type, severity: 0).matrix, identity)
        }
        for (partial, full) in [
            (VisionType.protanomaly, VisionType.protanopia),
            (.deuteranomaly, .deuteranopia),
            (.tritanomaly, .tritanopia),
            (.achromatomaly, .achromatopsia)
        ] {
            XCTAssertEqual(Simulation(type: partial, severity: 1).matrix, Simulation(type: full).matrix)
        }
        // 0.55 lies between published 0.5 and 0.6 entries; it is not a blend
        // of normal vision and the severity-1 matrix.
        let interpolated = Simulation(type: .protanomaly, severity: 0.55).matrix
        XCTAssertEqual(interpolated[0], 0.421757, accuracy: 0.000001)
        XCTAssertEqual(interpolated[1], 0.7242915, accuracy: 0.000001)
        XCTAssertEqual(interpolated[5], 0.0652875, accuracy: 0.000001)
    }

    func testNeutralColoursStayNeutral() {
        for type in VisionType.allCases {
            for severity in [0.0, 0.05, 0.5, 0.95, 1.0] {
                let matrix = Simulation(type: type, severity: severity).matrix
                for row in 0..<3 {
                    XCTAssertEqual(matrix[(row * 3)..<(row * 3 + 3)].reduce(0, +), 1, accuracy: 0.000002)
                }
            }
        }
    }
}
