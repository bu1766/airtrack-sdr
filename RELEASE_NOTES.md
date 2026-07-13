# AirTrack SDR 1.0.0

AirTrack SDR 1.0 is the first public macOS release focused on a simple, honest USB SDR experience: connect a supported receiver and start tracking aircraft without installing command-line tools.

## Included

- Native macOS app with an embedded live aircraft map
- Automatic RTL-SDR detection and one-device auto-start
- Multi-device selector shown only when needed
- Start and Stop controls with device-busy feedback
- RTL-SDR Blog V3/V4, generic RTL2832U, Nooelec NESDR, and bladeRF decoder support
- Callsign, route, origin, destination, aircraft model, altitude, speed, signal, icon, and trail display
- Local aircraft metadata database
- Apple Silicon and Intel build automation
- Loopback-only local server and protected receiver-control requests
- English-only interface and automated language check

## Important installation note

Version 1.0.0 community binaries are ad-hoc signed but not Apple-notarized because the project does not yet have a Developer ID certificate. On first launch, macOS may require right-clicking **AirTrack SDR** and choosing **Open**. The source, build workflow, checksums, and complete license notices are included for verification.

## Hardware scope

Airspy, SDRplay, HackRF, LimeSDR, and Funcube Dongle are not claimed as supported in v1.0. Their USB presence does not imply compatibility with the bundled ADS-B decoder.
