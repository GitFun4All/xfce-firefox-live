profile_xfcekiosk() {
	profile_virt
	# This ISO targets Hyper-V/QEMU guests and does not need the broad firmware set.
	kernel_firmware=""
	title="Xfce Firefox Live"
	desc="A minimal Alpine live desktop with Firefox, Xfce, and network tools."
	profile_abbrev="xfce"
	arch="x86_64"
	image_name="xfce-firefox-alpine"
	output_filename="xfce-firefox-alpine-${RELEASE}-${ARCH}.iso"
	hostname="xfce-kiosk"
	apks="alpine-base ${KIOSK_APKS}"
	apkovl=".alpine-aports/scripts/genapkovl-xfcekiosk.sh"
}

profile_firefoxonly() {
	profile_virt
	# Wired-only browser appliance; keep the VM-focused kernel without the
	# general firmware bundle used by the standard profile.
	kernel_firmware=""
	title="Firefox Only Wired Live"
	desc="A minimal Alpine live system that opens Firefox ESR with wired networking."
	profile_abbrev="firefox"
	arch="x86_64"
	image_name="firefox-only-alpine"
	output_filename="firefox-only-alpine-${RELEASE}-${ARCH}.iso"
	hostname="firefox-only"
	apks="alpine-base ${FIREFOX_ONLY_APKS}"
	apkovl=".alpine-aports/scripts/genapkovl-firefoxonly.sh"
}
