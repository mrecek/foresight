(function () {
  const storageKey = "foresight-theme"
  const preferences = ["dark", "light", "system"]
  const systemTheme = window.matchMedia("(prefers-color-scheme: dark)")

  function readPreference() {
    try {
      const stored = window.localStorage.getItem(storageKey)
      return preferences.includes(stored) ? stored : null
    } catch (_error) {
      return null
    }
  }

  let currentPreference = readPreference() || "dark"

  function resolvedTheme() {
    if (currentPreference === "system") return systemTheme.matches ? "dark" : "light"
    return currentPreference
  }

  function applyPreference() {
    const theme = resolvedTheme()
    const root = document.documentElement

    root.dataset.theme = theme
    root.dataset.themePreference = currentPreference
    root.style.colorScheme = theme
    document.querySelector("meta[name='theme-color']")?.setAttribute(
      "content",
      theme === "dark" ? "#09090b" : "#fafafa"
    )
    window.dispatchEvent(new CustomEvent("foresight:theme-changed", {
      detail: { preference: currentPreference, theme: theme }
    }))
  }

  function setPreference(preference) {
    if (!preferences.includes(preference)) return

    currentPreference = preference
    try {
      window.localStorage.setItem(storageKey, preference)
    } catch (_error) {
      // The selected theme still applies for this page when storage is unavailable.
    }
    applyPreference()
  }

  window.ForesightTheme = {
    apply: applyPreference,
    preference: function () { return currentPreference },
    setPreference: setPreference
  }

  systemTheme.addEventListener("change", function () {
    if (currentPreference === "system") applyPreference()
  })

  applyPreference()
})()
