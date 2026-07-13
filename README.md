# AirTrack SDR｜macOS 航班实时追踪

**插上支持的 USB 软件无线电，打开 App，就能在地图上查看附近飞机、航迹、航班路线和机型。**

AirTrack SDR 是一款面向普通用户的 macOS ADS-B 接收应用。无需安装 Homebrew、Python，无需输入终端命令，也不用另外配置浏览器。App 默认使用英文界面，并可在设备控制区一键切换为**简体中文**。

[下载最新版](https://github.com/bu1766/airtrack-sdr/releases/latest) · [查看支持设备](#支持的设备) · [English](#english)

![AirTrack SDR 实时显示新加坡航空航班、路线、机型和航迹](docs/airtrack-sdr-live.jpg)

## 主要功能

- 自动发现兼容的 USB SDR；只连接一台设备时自动选择
- 连接多台兼容设备时才显示设备选择器
- 实时地图、飞机图标、航迹、高度、速度、呼号和信号强度
- 显示航班出发地、目的地、航空公司和机型（信息可用时）
- **英文默认，简体中文可选**；语言选择会自动保存
- 清晰的“开始追踪／停止”设备控制，不必使用终端
- 提供 Apple Silicon 与 Intel Mac 安装包
- 飞机基础资料保存在本地；航线查询在联网时使用

## 支持的设备

AirTrack SDR 1.1 支持内置 FlightAware dump1090 解码器能够直接使用的设备：

- RTL-SDR Blog V3 / V4
- 使用 R820T、R820T2、R828D 或兼容调谐器的通用 RTL2832U 接收器
- 基于 RTL2832U 的 Nooelec NESDR 系列
- `libbladeRF` 支持的 Nuand bladeRF

Airspy、SDRplay、HackRF、LimeSDR 和 Funcube Dongle 暂不在 1.1 版支持范围内。检测到 USB 设备并不代表内置 ADS-B 解码器能够使用它，因此项目不会标注未经验证的兼容性。

## 安装与使用

1. 从 [GitHub Releases](https://github.com/bu1766/airtrack-sdr/releases/latest) 下载适合你 Mac 的 DMG。
2. 将 **AirTrack SDR** 拖入“应用程序”文件夹。
3. 连接 SDR 和 1090 MHz 天线。
4. 打开 AirTrack SDR；如果没有自动开始，点击 **Start Tracking**。
5. 如需中文，在设备控制区的 **Language** 中选择 **简体中文**。

本项目的社区安装包采用临时签名、尚未经过 Apple 公证。第一次打开时，可能需要在 Finder 中右键 AirTrack SDR，选择“打开”，再确认一次。**不加入 Apple Developer Program 也能使用。**

## 使用要求

- macOS 13 Ventura 或更高版本
- 一台支持的 SDR 接收器
- 1090 MHz 天线（普通套装天线也可开始体验）
- 地图瓦片、飞机照片和航线查询需要联网

## 常见问题

- **未找到支持的 SDR 设备**：重新直连 USB 接收器，避免使用无供电集线器，然后重开 App。
- **设备可能正被占用**：关闭 Gqrx、SatDump、SDR++ 或其他正在使用同一接收器的软件。
- **地图上没有飞机**：将天线垂直放在窗边并等待几分钟。ADS-B 接收高度依赖视距和天线位置。
- **有飞机但没有航线**：航线需要联网查询；私人、军用或不规则呼号可能没有公开路线。
- **切换语言后想恢复英文**：在设备控制区的语言菜单中选择 **English**。

## 隐私

飞机信号解码和设备控制都在 Mac 本地完成。为了查询出发地和目的地，AirTrack SDR 会把接收到的航班呼号和飞机位置发送给所配置的航线服务（`adsb.im`）。显示地图或飞机照片时，相应服务会收到正常的网络请求。

本地控制服务仅绑定 `127.0.0.1`，并在 8090–8190 范围内自动选择可用端口。

## 从源码构建

```bash
brew install dump1090-fa librtlsdr libbladerf libusb ncurses
./scripts/build-macos.sh
./scripts/verify-bundle.sh
```

DMG 和 SHA-256 校验文件会生成在 `dist/`。

## English

AirTrack SDR is a one-click ADS-B aircraft map for macOS. Connect a supported USB software-defined radio, open the app, and select **Start Tracking**. No Homebrew, Python, Terminal commands, or browser configuration is required.

The interface defaults to English. Choose **简体中文** from the **Language** menu in the device control panel to switch languages; the preference is saved locally.

### Highlights

- Automatic USB SDR discovery and one-device auto-selection
- Device picker appears only when multiple compatible receivers are attached
- Live aircraft map, icons, tracks, altitude, speed, callsign, route, and aircraft model
- English-first interface with optional Simplified Chinese
- Local decoder control with clear Start and Stop actions
- Apple Silicon and Intel release builds
- Local aircraft database; route lookup uses the internet when available

### Requirements and installation

AirTrack SDR requires macOS 13 Ventura or later, a supported receiver, and a 1090 MHz antenna. Download the correct DMG from [GitHub Releases](https://github.com/bu1766/airtrack-sdr/releases/latest), drag the app to Applications, connect the receiver, and open the app.

Community builds are ad-hoc signed and may require right-clicking the app and choosing **Open** once. Apple Developer Program membership is not required to use the app.

### Supported hardware

- RTL-SDR Blog V3 and V4
- Generic RTL2832U receivers using R820T, R820T2, R828D, or compatible tuners
- Nooelec NESDR models based on RTL2832U
- Nuand bladeRF devices supported by `libbladeRF`

Airspy, SDRplay, HackRF, LimeSDR, and Funcube Dongle are not claimed as supported in version 1.1 because the bundled decoder does not provide compatible input backends for them.

## License

AirTrack SDR is distributed under GPL-2.0-or-later. It contains modified tar1090 code and bundled GPL-compatible receiver components. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
