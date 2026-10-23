<script setup lang="ts">
import { ref } from 'vue'
import { STATUS_META, STATUS_ORDER, TYPE_META, TYPE_ORDER } from '@/utils/status'
import TypeIcon from '@/components/common/TypeIcon.vue'

defineProps<{ showTechnicians?: boolean; routeLabel?: string | null }>()

/**
 * Colapsada por defecto: la leyenda completa ocupaba el centro del mapa y
 * tapaba las órdenes. Colapsada deja una tira compacta de simbología.
 */
const expanded = ref(false)
</script>

<template>
  <div class="map-legend" :class="{ 'is-expanded': expanded }">
    <button
      type="button"
      class="map-legend__toggle"
      :aria-expanded="expanded"
      @click="expanded = !expanded"
    >
      <span class="map-legend__toggle-title">Leyenda</span>
      <span class="map-legend__strip" aria-hidden="true">
        <span
          v-for="status in STATUS_ORDER"
          :key="status"
          class="map-legend__swatch map-legend__swatch--sm"
          :style="{ background: STATUS_META[status].color }"
        />
        <span class="map-legend__strip-sep" />
        <span
          v-for="type in TYPE_ORDER"
          :key="type"
          class="map-legend__icon map-legend__icon--sm"
        >
          <TypeIcon :type="type" :size="13" color="#334155" />
        </span>
      </span>
      <span class="map-legend__caret" aria-hidden="true">
        {{ expanded ? '▾' : '▴' }}
      </span>
    </button>

    <div v-if="expanded" class="map-legend__panel">
      <p class="map-legend__title">Estado de la orden</p>
      <div class="map-legend__cols">
        <p v-for="status in STATUS_ORDER" :key="status" class="map-legend__row">
          <span
            class="map-legend__swatch"
            :style="{ background: STATUS_META[status].color }"
            aria-hidden="true"
          />
          <span>{{ STATUS_META[status].label }}</span>
        </p>
      </div>

      <p class="map-legend__title" style="margin-top: 10px">Tipo de trabajo</p>
      <div class="map-legend__cols">
        <p v-for="type in TYPE_ORDER" :key="type" class="map-legend__row">
          <span class="map-legend__icon">
            <TypeIcon :type="type" :size="15" color="#334155" />
          </span>
          <span>{{ TYPE_META[type].label }}</span>
        </p>
      </div>

      <p v-if="showTechnicians" class="map-legend__row" style="margin-top: 8px">
        <span class="map-legend__swatch" style="background: #0a2540" />
        <span>Cuadrilla (última ubicación conocida)</span>
      </p>

      <p class="map-legend__note">
        La ruta se dibuja como rectas entre paradas ordenadas:
        <strong>no es geometría vial ni cálculo de rutas</strong>.
        <span v-if="routeLabel"> {{ routeLabel }}</span>
      </p>
    </div>
  </div>
</template>

<style scoped>
.map-legend {
  max-width: none;
  padding: 0;
  overflow: hidden;
}

.map-legend.is-expanded {
  max-width: 306px;
}

.map-legend__toggle {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 7px 10px;
  background: transparent;
  border: 0;
}

.map-legend__toggle:hover {
  background: var(--ink-50);
}

.map-legend__toggle-title {
  font-size: 11px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--ink-500);
}

.map-legend__strip {
  display: flex;
  align-items: center;
  gap: 4px;
}

.map-legend__strip-sep {
  width: 1px;
  height: 14px;
  background: var(--ink-200);
  margin: 0 2px;
}

.map-legend__swatch--sm {
  width: 10px;
  height: 10px;
}

.map-legend__icon--sm {
  width: 14px;
  height: 14px;
}

.map-legend__caret {
  margin-left: auto;
  font-size: 10px;
  color: var(--ink-500);
}

.map-legend__panel {
  padding: 4px 10px 10px;
  max-height: 46vh;
  overflow-y: auto;
}

.map-legend__cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 10px;
}
</style>
