import XCTest

/// Trykker rundt i den hemmelige menu på en simulator med 100 sensor-målinger i sekundet
/// (samme belastning som på en rigtig iPhone) og tjekker, at valgene faktisk slår igennem.
final class PanelUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-fakeSensor", "-language", "en", "-mode", "normal", "-threshold2", "40", "-hasBackground", "NO", "-sound", "YES", "-soundVolume", "1", "-vibEnabled", "YES", "-vibStrength", "1", "-coinDot", "NO", "-tapReveal", "NO", "-splitLine", "YES", "-customTrue", "", "-customFalse", ""]
        app.launch()
    }

    private func openPanel() {
        _ = app.staticTexts["True or false?"].waitForExistence(timeout: 5)
        let corner = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.04))
        var opened = false
        for _ in 0..<3 where !opened {
            for _ in 0..<5 { corner.tap() }
            opened = app.buttons["doneButton"].waitForExistence(timeout: 4)
            if !opened { sleep(3) }   // lad tap-vinduet (2,5 s) løbe ud før næste forsøg
        }
        XCTAssertTrue(opened, "Menuen åbnede ikke")
        sleep(1)
    }

    private func scrollTo(_ el: XCUIElement, max: Int = 8) {
        var i = 0
        while !(el.exists && el.isHittable) && i < max { app.swipeUp(velocity: .slow); i += 1 }
        XCTAssertTrue(el.exists && el.isHittable, "Fandt ikke \(el)")
    }

    func testLanguageSwitchWorks() {
        openPanel()
        let dansk = app.segmentedControls["languagePicker"].buttons["Dansk"]
        scrollTo(dansk)
        dansk.tap()
        XCTAssertTrue(app.buttons["Færdig"].waitForExistence(timeout: 3), "Sproget skiftede ikke til dansk")
        let english = app.segmentedControls["languagePicker"].buttons["English"]
        english.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3), "Sproget skiftede ikke tilbage til engelsk")
    }

    func testSecretModeAndBackgroundOption() {
        openPanel()
        let secret = app.segmentedControls["modePicker"].buttons["Secret"]
        scrollTo(secret)
        secret.tap()
        XCTAssertTrue(secret.isSelected, "Hemmelig tilstand blev ikke valgt")
        XCTAssertTrue(app.buttons["backgroundPicker"].exists || app.otherElements["backgroundPicker"].exists, "Valg af egen baggrund mangler")
        // Luk menuen: hemmelig skærm vises (ingen startskærm-tekst)
        app.buttons["doneButton"].tap()
        XCTAssertFalse(app.staticTexts["True or false?"].waitForExistence(timeout: 2), "Startskærmen blev vist i hemmelig tilstand")
    }

    func testThresholdSliderWorks() {
        openPanel()
        let slider = app.sliders["thresholdSlider"]
        scrollTo(slider)
        let value = app.staticTexts["thresholdValue"]
        let before = value.label
        slider.adjust(toNormalizedSliderPosition: 0.8)
        let changed = NSPredicate(format: "label != %@", before)
        expectation(for: changed, evaluatedWith: value)
        waitForExpectations(timeout: 3)
        XCTAssertNotEqual(value.label, "40 µT", "Skyderen ændrede ikke tærsklen")
    }

    func testVibrationDelaySliderWorks() {
        openPanel()
        let slider = app.sliders["vibDelaySlider"]
        scrollTo(slider)
        let before = slider.value as? String
        slider.adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertNotEqual(slider.value as? String, before, "Vibrations-skyderen reagerede ikke")
    }

    func testSoundToggleAndVolume() {
        openPanel()
        let slider = app.sliders["volumeSlider"]
        scrollTo(slider)
        let value = app.staticTexts["volumeValue"]
        XCTAssertEqual(value.label, "100 %")
        slider.adjust(toNormalizedSliderPosition: 0.3)
        expectation(for: NSPredicate(format: "label != %@", "100 %"), evaluatedWith: value)
        waitForExpectations(timeout: 3)

        let toggle = app.switches["soundToggle"]
        scrollTo(toggle)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()   // selve kontakten i højre side
        XCTAssertFalse(app.sliders["volumeSlider"].waitForExistence(timeout: 2), "Lyd blev ikke slået fra")
    }

    func testVibrationStrengthAndOff() {
        openPanel()
        let slider = app.sliders["vibStrengthSlider"]
        scrollTo(slider)
        let value = app.staticTexts["vibStrengthValue"]
        XCTAssertEqual(value.label, "100 %")
        slider.adjust(toNormalizedSliderPosition: 0.2)
        expectation(for: NSPredicate(format: "label != %@", "100 %"), evaluatedWith: value)
        waitForExpectations(timeout: 3)
        let toggle = app.switches["vibToggle"]
        scrollTo(toggle)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertFalse(app.sliders["vibStrengthSlider"].waitForExistence(timeout: 2), "Vibration blev ikke slået fra")
    }

    func testCoinDotToggle() {
        openPanel()
        let toggle = app.switches["dotToggle"]
        scrollTo(toggle)
        let before = toggle.value as? String
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value != %@", before ?? ""), evaluatedWith: toggle)
        waitForExpectations(timeout: 3)
    }

    func testCustomResultTexts() {
        openPanel()
        let field = app.textFields["customFalseField"]
        scrollTo(field)
        field.tap()
        field.typeText("Nice try!")
        XCTAssertEqual(field.value as? String, "Nice try!", "Egen tekst blev ikke gemt i feltet")
        app.swipeDown(velocity: .slow)   // luk tastaturet
        let preset = app.buttons["preset0"]
        scrollTo(preset)
        preset.tap()
        XCTAssertEqual(app.textFields["customFalseField"].value as? String, "LIE!", "Forslag virkede ikke")
        let reset = app.buttons["presetDefault"]
        reset.tap()
        XCTAssertNotEqual(app.textFields["customFalseField"].value as? String, "LIE!", "Standard-forslag ryddede ikke teksten")
    }

    func testLearnMyMagnetOpens() {
        openPanel()
        let link = app.buttons["learnLink"]
        scrollTo(link)
        link.tap()
        XCTAssertTrue(app.navigationBars["Learn my magnet"].waitForExistence(timeout: 3), "Lær min magnet åbnede ikke")
        XCTAssertTrue(app.buttons["Start"].firstMatch.exists, "Start-knap mangler")
    }

    func testTapRevealToggleInMenu() {
        openPanel()
        let toggle = app.switches["tapRevealToggle"]
        scrollTo(toggle)
        XCTAssertFalse(app.switches["splitLineToggle"].exists)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(app.switches["splitLineToggle"].waitForExistence(timeout: 3), "Skillestreg-valget dukkede ikke op")
    }

    /// Tryk øverst = Sandt, nederst = Falsk.
    func testTapTopAndBottomReveals() {
        app.terminate()
        if let i = app.launchArguments.firstIndex(of: "-tapReveal") { app.launchArguments[i + 1] = "YES" }
        app.launch()
        XCTAssertTrue(app.staticTexts["True or false?"].waitForExistence(timeout: 5))
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.25))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.8))

        center.tap()
        XCTAssertTrue(app.staticTexts["Thinking"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["splitLine"].exists || app.descendants(matching: .any)["splitLine"].exists, "Skillestregen mangler")
        top.tap()
        let result = app.staticTexts["resultText"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertEqual(result.label, "True", "Øverste halvdel gav ikke Sandt")

        sleep(1)
        center.tap()   // tilbage til start
        XCTAssertTrue(app.staticTexts["True or false?"].waitForExistence(timeout: 3))
        center.tap()
        XCTAssertTrue(app.staticTexts["Thinking"].waitForExistence(timeout: 3))
        bottom.tap()
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        XCTAssertEqual(result.label, "False", "Nederste halvdel gav ikke Falsk")
    }
}
