// Reports the current theme to the native Flutter shell (see the
// 'ThemeChannel' JavaScript channel in web_app_screen.dart) so it can match
// the system status/navigation bar color to whatever's actually on screen -
// a no-op outside the app shell (plain browser tab, no ThemeChannel).
export function reportThemeToNativeShell(isDark: boolean): void {
  (window as unknown as { ThemeChannel?: { postMessage: (message: string) => void } })
    .ThemeChannel?.postMessage(isDark ? 'dark' : 'light');
}
