<script setup lang="ts">
import type { OperationsFilters, WorkOrderStatus, WorkOrderType } from '@/types/domain'
import { STATUS_META, STATUS_ORDER, TYPE_META, TYPE_ORDER } from '@/utils/status'
import { UNASSIGNED_FILTER } from '@/utils/filters'

defineProps<{
  filters: OperationsFilters
  districts: string[]
  zones: string[]
  technicians: Array<{ id: string; fullName: string }>
  hasFilters: boolean
}>()

const emit = defineEmits<{
  (event: 'update', partial: Partial<OperationsFilters>): void
  (event: 'reset'): void
}>()

function onStatus(event: Event): void {
  emit('update', {
    status: (event.target as HTMLSelectElement).value as WorkOrderStatus | 'todos',
  })
}

function onType(event: Event): void {
  emit('update', {
    type: (event.target as HTMLSelectElement).value as WorkOrderType | 'todos',
  })
}

function onText(field: 'search' | 'district' | 'zone' | 'technicianId') {
  return (event: Event) => {
    emit('update', { [field]: (event.target as HTMLInputElement | HTMLSelectElement).value })
  }
}
</script>

<template>
  <div class="filters-grid">
    <div class="field field--full">
      <label for="filter-search">Buscar</label>
      <input
        id="filter-search"
        class="input"
        type="search"
        placeholder="Suministro, código, cliente o dirección"
        :value="filters.search"
        @input="onText('search')($event)"
      />
    </div>

    <div class="field">
      <label for="filter-status">Estado</label>
      <select id="filter-status" class="select" :value="filters.status" @change="onStatus">
        <option value="todos">Todos</option>
        <option v-for="status in STATUS_ORDER" :key="status" :value="status">
          {{ STATUS_META[status].label }}
        </option>
      </select>
    </div>

    <div class="field">
      <label for="filter-type">Tipo</label>
      <select id="filter-type" class="select" :value="filters.type" @change="onType">
        <option value="todos">Todos</option>
        <option v-for="type in TYPE_ORDER" :key="type" :value="type">
          {{ TYPE_META[type].label }}
        </option>
      </select>
    </div>

    <div class="field">
      <label for="filter-district">Distrito</label>
      <select
        id="filter-district"
        class="select"
        :value="filters.district"
        @change="onText('district')($event)"
      >
        <option value="todos">Todos</option>
        <option v-for="district in districts" :key="district" :value="district">
          {{ district }}
        </option>
      </select>
    </div>

    <div class="field">
      <label for="filter-zone">Zona</label>
      <select
        id="filter-zone"
        class="select"
        :value="filters.zone"
        @change="onText('zone')($event)"
      >
        <option value="todos">Todas</option>
        <option v-for="zone in zones" :key="zone" :value="zone">{{ zone }}</option>
      </select>
    </div>

    <div class="field field--full">
      <label for="filter-technician">Técnico asignado</label>
      <select
        id="filter-technician"
        class="select"
        :value="filters.technicianId"
        @change="onText('technicianId')($event)"
      >
        <option value="todos">Todos</option>
        <option :value="UNASSIGNED_FILTER">Sin asignar</option>
        <option v-for="tech in technicians" :key="tech.id" :value="tech.id">
          {{ tech.fullName }}
        </option>
      </select>
    </div>

    <div class="field">
      <label for="filter-from">Desde</label>
      <input
        id="filter-from"
        class="input"
        type="date"
        :value="filters.dateFrom"
        @change="emit('update', { dateFrom: ($event.target as HTMLInputElement).value })"
      />
    </div>

    <div class="field">
      <label for="filter-to">Hasta</label>
      <input
        id="filter-to"
        class="input"
        type="date"
        :value="filters.dateTo"
        @change="emit('update', { dateTo: ($event.target as HTMLInputElement).value })"
      />
    </div>

    <div class="field--full">
      <button
        type="button"
        class="btn btn--sm btn--ghost btn--block"
        :disabled="!hasFilters"
        @click="emit('reset')"
      >
        Limpiar filtros
      </button>
    </div>
  </div>
</template>
