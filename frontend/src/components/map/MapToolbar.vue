<script setup lang="ts">
import type { SelectionMode } from '@/stores/operations'

defineProps<{
  selectionMode: SelectionMode
  selectionCount: number
  showTechnicians: boolean
  routeAvailable: boolean
  canDispatch: boolean
  proximityTechnicianId: string
  technicians: Array<{ id: string; fullName: string }>
}>()

const emit = defineEmits<{
  (event: 'toggle-polygon'): void
  (event: 'close-polygon'): void
  (event: 'clear-selection'): void
  (event: 'toggle-technicians'): void
  (event: 'fit-all'): void
  (event: 'fit-route'): void
  (event: 'zoom-in'): void
  (event: 'zoom-out'): void
  (event: 'proximity', technicianId: string): void
  (event: 'update:proximityTechnicianId', value: string): void
}>()

function onProximityChange(event: Event): void {
  emit('update:proximityTechnicianId', (event.target as HTMLSelectElement).value)
}
</script>

<template>
  <div class="map-toolbar">
    <div class="toolbar-group">
      <button type="button" class="toolbar-btn" title="Acercar" @click="emit('zoom-in')">
        +
      </button>
      <button type="button" class="toolbar-btn" title="Alejar" @click="emit('zoom-out')">
        −
      </button>
      <button type="button" class="toolbar-btn" title="Ver todas las órdenes" @click="emit('fit-all')">
        ⤢ Ajustar
      </button>
    </div>

    <div class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn"
        :class="{ 'is-active': selectionMode === 'polygon' }"
        :title="canDispatch ? 'Dibujar polígono de selección' : 'Solo despacho puede seleccionar áreas'"
        :disabled="!canDispatch"
        @click="emit('toggle-polygon')"
      >
        ✎ Polígono
      </button>
      <button
        type="button"
        class="toolbar-btn"
        title="Cerrar el polígono actual"
        :disabled="selectionMode !== 'polygon'"
        @click="emit('close-polygon')"
      >
        ✓ Cerrar
      </button>
      <button
        type="button"
        class="toolbar-btn"
        :disabled="!selectionCount"
        @click="emit('clear-selection')"
      >
        ✕ Limpiar ({{ selectionCount }})
      </button>
    </div>

    <div class="toolbar-group">
      <button
        type="button"
        class="toolbar-btn"
        :class="{ 'is-active': showTechnicians }"
        title="Mostrar u ocultar cuadrillas"
        @click="emit('toggle-technicians')"
      >
        ⛟ Cuadrillas
      </button>
      <button
        type="button"
        class="toolbar-btn"
        :disabled="!routeAvailable"
        title="Enfocar la secuencia de paradas de la ruta"
        @click="emit('fit-route')"
      >
        ⌁ Ruta
      </button>
    </div>

    <div v-if="canDispatch" class="toolbar-group toolbar-group--proximity">
      <label class="visually-hidden" for="proximity-select">
        Cuadrilla para selección por proximidad
      </label>
      <select
        id="proximity-select"
        class="select select--compact"
        :value="proximityTechnicianId"
        @change="onProximityChange"
      >
        <option value="">Cerca de cuadrilla…</option>
        <option v-for="tech in technicians" :key="tech.id" :value="tech.id">
          {{ tech.fullName }}
        </option>
      </select>
      <button
        type="button"
        class="toolbar-btn"
        :disabled="!proximityTechnicianId"
        title="Seleccionar órdenes cercanas a la cuadrilla (sin cálculo de rutas)"
        @click="emit('proximity', proximityTechnicianId)"
      >
        Seleccionar 3 km
      </button>
    </div>
  </div>
</template>

<style scoped>
.toolbar-group--proximity {
  align-items: center;
  gap: 6px;
  padding: 5px 7px;
}

.select--compact {
  width: auto;
  max-width: 190px;
  padding: 4px 6px;
  font-size: 12.5px;
}
</style>
