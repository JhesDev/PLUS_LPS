<script setup lang="ts">
withDefaults(
  defineProps<{
    kind: 'loading' | 'error' | 'empty'
    title: string
    message?: string
    hint?: string
    actionLabel?: string
  }>(),
  {
    message: '',
    hint: '',
    actionLabel: '',
  },
)

defineEmits<{ (event: 'action'): void }>()
</script>

<template>
  <div class="state-panel">
    <div class="state-panel__box">
      <div v-if="kind === 'loading'" class="spinner" aria-hidden="true" />

      <p class="state-panel__title">{{ title }}</p>

      <p v-if="message" class="state-panel__message">{{ message }}</p>

      <p v-if="hint" class="state-panel__hint">{{ hint }}</p>

      <button
        v-if="actionLabel"
        type="button"
        class="btn btn--primary"
        @click="$emit('action')"
      >
        {{ actionLabel }}
      </button>
    </div>
  </div>
</template>
