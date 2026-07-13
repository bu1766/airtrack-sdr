"use strict";

(() => {
  const connectButton = document.getElementById("receiver-connect");
  const disconnectButton = document.getElementById("receiver-disconnect");
  const statusDot = document.getElementById("receiver-status-dot");
  const statusText = document.getElementById("receiver-status-text");
  const deviceRow = document.getElementById("receiver-device-row");
  const deviceSelect = document.getElementById("receiver-device");
  let busy = false;

  async function refreshDevices() {
    try {
      const response = await fetch("/api/receiver/devices", {cache: "no-store"});
      const payload = await response.json();
      const devices = Array.isArray(payload.devices) ? payload.devices : [];
      const previous = deviceSelect.value;
      deviceSelect.replaceChildren(...devices.map((device) => {
        const option = document.createElement("option");
        option.value = device.id;
        option.textContent = device.serial ? `${device.name} · ${device.serial}` : device.name;
        return option;
      }));
      if (devices.some((device) => device.id === previous)) deviceSelect.value = previous;
      deviceRow.classList.toggle("hidden", devices.length < 2);
      return devices;
    } catch (_error) {
      deviceRow.classList.add("hidden");
      return [];
    }
  }

  function render(payload) {
    const connected = Boolean(payload.connected);
    statusDot.className = connected ? "connected" : "disconnected";
    statusText.textContent = payload.message || (connected ? "RTL-SDR Connected" : "RTL-SDR Disconnected");
    connectButton.disabled = busy || connected;
    disconnectButton.disabled = busy || !connected;
    if (!connected) {
      const updateError = document.getElementById("update_error");
      if (updateError) updateError.classList.add("hidden");
    }
  }

  async function request(action) {
    busy = action !== "status";
    if (busy) {
      connectButton.disabled = true;
      disconnectButton.disabled = true;
      statusText.textContent = action === "start" ? "Connecting…" : "Disconnecting…";
    }
    try {
      const options = action === "status" ? {cache: "no-store"} : {
        method: "POST",
        headers: {"Content-Type": "application/json", "X-ADSB-Control": "1"},
        body: action === "start" ? JSON.stringify({device: deviceSelect.value || null}) : "{}",
      };
      const response = await fetch(`/api/receiver/${action}`, options);
      const payload = await response.json();
      render(payload);
    } catch (_error) {
      render({connected: false, message: "Local Control Service Offline"});
    } finally {
      busy = false;
    }
  }

  connectButton.addEventListener("click", async () => {
    await refreshDevices();
    request("start");
  });
  disconnectButton.addEventListener("click", () => request("stop"));
  refreshDevices();
  request("status");
  window.setInterval(refreshDevices, 5000);
  window.setInterval(() => request("status"), 2500);
})();
