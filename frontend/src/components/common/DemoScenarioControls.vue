<script setup lang="ts">
import type { DemoScenario } from '@/services/operationsRepository'
import { useSessionStore } from '@/stores/session'

const session = useSessionStore()

const OPTIONS: Array<{ value: DemoScenario; label: string }> = [
  { value: 'ready', label: 'Listo' },
  { value: 'empty', label: 'Vacío' },
  { value: 'error', label: 'Error' },
  { value: 'slow', label: 'Lento' },
]
</script>

<template>
  <span class="scenario-controls">
    <span class="scenario-controls__label">Estado demo:</span>
    <button
      v-for="option in OPTIONS"
      :key="option.value"
      type="button"
      class="scenario-controls__btn"
      :class="{ 'is-active': session.scenario === option.value }"
      :title="`Cargar el escenario de demostración «${option.label}»`"
      @click="session.setScenario(option.value)"
    >
      {{ option.label }}
    </button>
  </span>
</template>

<style scoped>
.scenario-controls {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.scenario-controls__label {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  opacity: 0.8;
}

.scenario-controls__btn {
  padding: 2px 7px;
  border-radius: 999px;
  border: 1px solid #f0cc74;
  background: transparent;
  color: #7c4a03;
  font-size: 11.5px;
  font-weight: 700;
}

.scenario-controls__btn:hover {
  background: rgba(240, 204, 116, 0.35);
}

.scenario-controls__btn.is-active {
  background: var(--warning);
  color: #3f2a02;
  border-color: #c98d05;
}
</style>
