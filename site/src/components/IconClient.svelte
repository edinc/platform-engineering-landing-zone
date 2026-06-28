<script lang="ts" module>
  export const ICONS: Record<string, string> = {
    "arrow-right": "M5 12h14M13 6l6 6-6 6",
    "arrow-up-right": "M7 17 17 7M8 7h9v9",
    check: "M5 12.5l4.5 4.5L19 7.5",
    layers: "M12 4 3 9l9 5 9-5-9-5ZM3 14l9 5 9-5M3 9v0",
    route: "M6 19a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM18 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM18 11v2a3 3 0 0 1-3 3H9",
    coins: "M9 12a6 3 0 1 0 0-6 6 3 0 0 0 0 6ZM3 9v6c0 1.7 2.7 3 6 3M15 9.4c1.8.4 3 1.4 3 2.6v6c0 1.7-2.7 3-6 3-1.2 0-2.3-.2-3.2-.5",
    users:
      "M16 18v-1a3 3 0 0 0-3-3H7a3 3 0 0 0-3 3v1M10 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM20 18v-1a3 3 0 0 0-2.3-2.9M15 5.1a3 3 0 0 1 0 5.8",
    terminal: "M6 8l3.5 3.5L6 15M13 16h6M4 4h16v16H4z",
    compass: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM15.5 8.5l-1.8 5.2-5.2 1.8 1.8-5.2 5.2-1.8Z",
    cpu: "M9 3v2M15 3v2M9 19v2M15 19v2M3 9h2M3 15h2M19 9h2M19 15h2M6 6h12v12H6zM10 10h4v4h-4z",
    shield: "M12 3 5 6v6c0 4 3 6.5 7 9 4-2.5 7-5 7-9V6l-7-3ZM9.5 12l1.8 1.8 3.5-3.6",
    lock: "M7 11V8a5 5 0 0 1 10 0v3M6 11h12v9H6zM12 15v2",
    "git-branch":
      "M7 4v12M7 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM7 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM18 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM18 8c0 5-5 4-5 8",
    boxes:
      "M12 8 7 5.5 2 8l5 2.5L12 8ZM12 8l5-2.5L22 8l-5 2.5L12 8ZM7 16l-5-2.5V8M12 18.5 7 16v-5.5M17 16l5-2.5V8M12 18.5 17 16v-5.5",
    play: "M7 5l12 7-12 7z",
    pause: "M8 5v14M16 5v14",
    flag: "M5 21V4M5 4l9 1.5L5 4ZM5 5.5l9 1.5 5-1-5-1.5",
  };
</script>

<script lang="ts">
  let { name, size = 20, stroke = 1.6 }: { name: string; size?: number; stroke?: number } = $props();
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width={stroke}
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
  focusable="false"
>
  <path d={ICONS[name] ?? ""}></path>
</svg>
