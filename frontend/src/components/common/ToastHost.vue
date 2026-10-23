<script setup lang="ts">
import { useToastStore } from '@/stores/toasts'

const toasts = useToastStore()
</script>

<template>
  <div class="toast-host" aria-live="polite">
    <div
      v-for="toast in toasts.items"
      :key="toast.id"
      class="toast"
      :class="{ 'toast--error': toast.kind === 'error', 'toast--success': toast.kind === 'success' }"
    >
      <span class="grow">{{ toast.message }}</span>
      <button
        type="button"
        class="toast__close"
        aria-label="Cerrar aviso"
        @click="toasts.dismiss(toast.id)"
      >
        ✕
      </button>
    </div>
  </div>
</template>

<style scoped>
.toast__close {
  background: transparent;
  border: 0;
  color: inherit;
  opacity: 0.7;
  font-size: 12px;
}

.toast__close:hover {
  opacity: 1;
}
</style>
