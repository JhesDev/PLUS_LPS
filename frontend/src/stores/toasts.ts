import { defineStore } from 'pinia'
import { ref } from 'vue'

export type ToastKind = 'info' | 'success' | 'error'

export interface Toast {
  id: number
  kind: ToastKind
  message: string
}

let counter = 0

export const useToastStore = defineStore('toasts', () => {
  const items = ref<Toast[]>([])

  function push(message: string, kind: ToastKind = 'info'): void {
    const id = ++counter
    items.value = [...items.value, { id, kind, message }]
    setTimeout(() => dismiss(id), kind === 'error' ? 7000 : 4500)
  }

  function dismiss(id: number): void {
    items.value = items.value.filter((toast) => toast.id !== id)
  }

  return {
    items,
    push,
    dismiss,
    info: (message: string) => push(message, 'info'),
    success: (message: string) => push(message, 'success'),
    error: (message: string) => push(message, 'error'),
  }
})
