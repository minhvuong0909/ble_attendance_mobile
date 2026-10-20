/** Giao diện sáng/tối theo hệ thống (thêm/bỏ lớp `dark` trên <html>). */
export function initTheme(): void {
  const query = window.matchMedia('(prefers-color-scheme: dark)')
  const apply = () => document.documentElement.classList.toggle('dark', query.matches)
  apply()
  query.addEventListener('change', apply)
}
