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
