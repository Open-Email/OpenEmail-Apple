.PHONY: testflight

# Targets

testflight:
	@scripts/update_version.sh $(version)
	@scripts/build_appstore_release.sh
