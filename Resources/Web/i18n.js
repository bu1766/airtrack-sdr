"use strict";

(() => {
  const STORAGE_KEY = "airtrack-language";
  const supported = new Set(["en", "zh-CN"]);
  const zh = {
    "Language": "语言",
    "Device": "设备",
    "Start Tracking": "开始追踪",
    "Stop": "停止",
    "Checking Device…": "正在检查设备…",
    "Connecting…": "正在连接…",
    "Disconnecting…": "正在断开…",
    "Local Control Service Offline": "本地控制服务离线",
    "No Supported SDR Device Found": "未找到支持的 SDR 设备",
    "SDR Disconnected": "SDR 已断开",
    "Unable to Open SDR — It May Be in Use": "无法打开 SDR——设备可能正被其他程序占用",
    "Unable to Start Decoder": "无法启动解码器",
    "Decoder Is Missing": "缺少解码器",
    "ROUTE": "航线",
    "Route": "航线",
    "FROM": "出发地",
    "TO": "目的地",
    "AIRCRAFT": "机型",
    "Reg.:": "注册号：",
    "Airline:": "航空公司：",
    "DB flags:": "数据库标记：",
    "Type:": "机型代码：",
    "Type code:": "机型代码：",
    "Type Desc.:": "机型描述：",
    "Altitude:": "高度：",
    "Speed:": "速度：",
    "Source:": "数据源：",
    "RSSI:": "信号：",
    "Groundspeed:": "地速：",
    "Squawk": "应答机代码",
    "Category": "类别",
    "Track": "航向",
    "Vert. Rate": "垂直速度",
    "Baro. Altitude": "气压高度",
    "WGS84 Altitude": "WGS84 高度",
    "Ground Track": "地面航迹",
    "True Heading": "真航向",
    "Magnetic Heading": "磁航向",
    "Total Aircraft:": "飞机总数：",
    "With Position:": "有位置数据：",
    "Messages:": "消息：",
    "History:": "历史：",
    "positions": "个位置",
    "/sec": "/秒",
    "Search": "搜索",
    "Search:": "搜索：",
    "Filters": "筛选",
    "Columns": "列",
    "Clear Search": "清除搜索",
    "Jump": "跳转",
    "Clear": "清除",
    "Jump to Airport or Latitude, Longitude:": "跳转至机场或经纬度：",
    "Text and Icon size:": "文字和图标大小：",
    "Icon size multiplier:": "图标大小倍数：",
    "Units:": "单位：",
    "Aeronautical": "航空",
    "Metric": "公制",
    "Imperial": "英制",
    "Ground Vehicles": "地面车辆",
    "Non-ICAO Targets (radar track / airframe unknown)": "非 ICAO 目标（雷达航迹／机体未知）",
    "Reset All Settings": "重置所有设置",
    "Reset": "重置",
    "Set": "设置",
    "Standard": "标准",
    "From Plane": "来自飞机",
    "Altimeter:": "高度表：",
    "Map Help": "地图帮助",
    "FAQ": "常见问题",
    "Filter": "筛选",
    "Filter by altitude:": "按高度筛选：",
    "Filter by source:": "按数据源筛选：",
    "Filter by DB flags:": "按数据库标记筛选：",
    "Problem fetching data from the server:": "从本地服务获取数据时出现问题：",
    "Seems the decoder / receiver / backend isn't working correctly!": "解码器、接收器或本地服务似乎未正常运行！",
    "No": "否",
    "Date:": "日期：",
    "Time:": "时间：",
    "UTC Date:": "UTC 日期：",
    "Distance": "距离",
    "Direction (from)": "方向（来自）",
    "Last Seen": "最后发现",
    "Last Pos.": "最后位置",
    "Msg. Rate": "消息速率",
    "Source": "数据源",
    "Ground:": "地面：",
    "Barometric": "气压",
    "Indicated:": "指示：",
    "Magnetic Decl.": "磁偏角",
    "Aircraft trails": "飞机航迹",
    "Aircraft positions": "飞机位置",
    "Toggle Sidebar": "切换侧栏",
    "Expand Sidebar": "展开侧栏",
    "Aircraft Photo": "飞机照片",
    "Reported flight origin and destination according to adsbdb.com": "根据在线航班数据库估算的出发地和目的地",
    "Estimated route based on the active callsign": "根据当前呼号估算的航线",
    "SDR Device": "SDR 设备",
    "RTL-SDR Device Control": "SDR 设备控制",
    "Interface Language": "界面语言"
  };

  const originalText = new WeakMap();
  const trackedText = new Set();
  const originalAttrs = new WeakMap();
  const trackedElements = new Set();
  let language = supported.has(localStorage.getItem(STORAGE_KEY)) ? localStorage.getItem(STORAGE_KEY) : "en";

  function translated(value) {
    if (language !== "zh-CN") return value;
    const trimmed = value.trim();
    if (!trimmed || !zh[trimmed]) return value;
    return value.replace(trimmed, zh[trimmed]);
  }

  function translateTextNode(node) {
    if (!node.parentElement || node.parentElement.closest("[data-i18n-ignore]")) return;
    if (!originalText.has(node)) {
      originalText.set(node, node.nodeValue || "");
      trackedText.add(node);
    }
    const original = originalText.get(node);
    const target = language === "en" ? original : translated(original);
    if (node.nodeValue !== target) node.nodeValue = target;
  }

  function translateElement(element) {
    if (element.closest("[data-i18n-ignore]")) return;
    if (!originalAttrs.has(element)) originalAttrs.set(element, {});
    const stored = originalAttrs.get(element);
    ["title", "aria-label", "placeholder"].forEach((name) => {
      if (!element.hasAttribute(name) && stored[name] === undefined) return;
      if (stored[name] === undefined) stored[name] = element.getAttribute(name);
      const original = stored[name];
      if (original !== null) element.setAttribute(name, language === "en" ? original : translated(original));
    });
    trackedElements.add(element);
  }

  function translateTree(root = document.body) {
    if (!root) return;
    if (root.nodeType === Node.TEXT_NODE) {
      translateTextNode(root);
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE) return;
    translateElement(root);
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      if (node.nodeType === Node.TEXT_NODE) translateTextNode(node);
      else translateElement(node);
    }
  }

  function forgetTree(root) {
    if (root.nodeType === Node.TEXT_NODE) {
      trackedText.delete(root);
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE) return;
    trackedElements.delete(root);
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      if (node.nodeType === Node.TEXT_NODE) trackedText.delete(node);
      else trackedElements.delete(node);
    }
  }

  function setLanguage(next) {
    language = supported.has(next) ? next : "en";
    localStorage.setItem(STORAGE_KEY, language);
    document.documentElement.lang = language;
    trackedText.forEach(translateTextNode);
    trackedElements.forEach(translateElement);
    translateTree(document.body);
    document.dispatchEvent(new CustomEvent("airtrack-language-changed", {detail: {language}}));
  }

  function translateStatus(message) {
    if (language !== "zh-CN" || !message) return message;
    if (zh[message]) return zh[message];
    let match = message.match(/^(\d+) SDR Devices? Ready$/);
    if (match) return `${match[1]} 个 SDR 设备已就绪`;
    match = message.match(/^(.*) Connected$/);
    if (match) return `${match[1]} 已连接`;
    return message;
  }

  window.airTrackI18n = {
    get language() { return language; },
    setLanguage,
    t(key) { return language === "zh-CN" ? (zh[key] || key) : key; },
    translateStatus,
  };

  const selector = document.getElementById("receiver-language");
  if (selector) {
    selector.value = language;
    selector.addEventListener("change", () => setLanguage(selector.value));
  }
  translateTree(document.body);
  setLanguage(language);

  const observer = new MutationObserver((records) => {
    records.forEach((record) => {
      record.removedNodes.forEach(forgetTree);
      if (language === "zh-CN") record.addedNodes.forEach(translateTree);
    });
  });
  observer.observe(document.body, {childList: true, subtree: true});
})();
