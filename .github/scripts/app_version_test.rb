# frozen_string_literal: true

require "minitest/autorun"
require_relative "app_version"

class AppVersionTest < Minitest::Test
  def test_release_version_comes_from_project_instead_of_build_date
    assert_equal "2026.11", AppVersion.for_build(project: project("2026.11"))
    assert_equal "2027.1", AppVersion.for_build(project: project("2027.1"))
  end

  def test_rejects_app_and_watch_version_mismatch
    assert_raises(ArgumentError) do
      AppVersion.for_build(project: project("2026.11", watch: "2026.11.6"))
    end
  end

  def test_rejects_extension_version_mismatch
    assert_raises(ArgumentError) do
      AppVersion.for_build(project: project("2026.11", background: "0.7.4"))
    end
  end

  def test_ci_override_must_match_the_upload_version
    assert_equal "2026.11", AppVersion.for_build(project: project("2026.11"), override: "2026.11")
    assert_raises(ArgumentError) do
      AppVersion.for_build(project: project("2026.11"), override: "2026.11.6")
    end
  end

  def test_rejects_invalid_release_versions
    %w[2026 2026.01 2026.11-alpha 2026.11.6.1].each do |invalid|
      assert_raises(ArgumentError) { AppVersion.for_build(project: project(invalid)) }
    end
  end

  def test_project_plists_and_ci_use_the_same_marketing_version
    configuration = JSON.parse(File.read(File.expand_path("../../Project.json", __dir__)))
    version = AppVersion.for_build(project: configuration)
    assert_match(/\A[1-9][0-9]*\.([1-9]|1[0-2])\z/, version)
    ["Sure", "Sure Watch", "Sure FinanceKit Background"].each do |name|
      target = configuration.fetch("targets").fetch(name)
      assert_equal version, target.fetch("settings").fetch("base").fetch("MARKETING_VERSION")
      assert_equal "$(MARKETING_VERSION)", target.fetch("info").fetch("properties").fetch("CFBundleShortVersionString")
      refute target.fetch("preBuildScripts", []).any? { |phase| phase.fetch("script").include?("app_version.rb") },
        "A build script must not rewrite the uploaded version"
      refute target.fetch("settings").fetch("base").key?("INFOPLIST_FILE"), "Use the project-generated plist"
    end

    extension = configuration.fetch("targets").fetch("Sure FinanceKit Background")
    assert_equal "extensionkit-extension", extension.fetch("type")
    assert_equal "am.sure.insights.financekit-background", extension.fetch("settings").fetch("base").fetch("PRODUCT_BUNDLE_IDENTIFIER")
    assert_equal "com.apple.financekit.background-delivery", extension.fetch("info").fetch("properties").fetch("EXAppExtensionAttributes").fetch("EXExtensionPointIdentifier")
    assert_equal "$(CURRENT_PROJECT_VERSION)", extension.fetch("info").fetch("properties").fetch("CFBundleVersion")
    shared_keychain_group = "$(AppIdentifierPrefix)am.sure.insights.financekit"
    assert_equal shared_keychain_group, extension.fetch("info").fetch("properties").fetch("SureFinanceKitKeychainAccessGroup")
    assert_equal shared_keychain_group, configuration.fetch("targets").fetch("Sure").fetch("info").fetch("properties").fetch("SureFinanceKitKeychainAccessGroup")
    entitlements = File.read(File.expand_path("../../FinanceKitBackground/FinanceKitBackground.entitlements", __dir__))
    assert_includes entitlements, "com.apple.developer.financekit"
    assert_includes entitlements, "group.am.sure.insights.financekit"
    assert_includes entitlements, "$(AppIdentifierPrefix)am.sure.insights.financekit"
  end

  private

  def project(version, watch: version, background: version)
    {
      "targets" => {
        "Sure" => target(version),
        "Sure Watch" => target(watch),
        "Sure FinanceKit Background" => target(background)
      }
    }
  end

  def target(version)
    { "settings" => { "base" => { "MARKETING_VERSION" => version } } }
  end
end
