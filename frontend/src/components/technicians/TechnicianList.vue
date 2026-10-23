<script setup lang="ts">
import type { Technician } from '@/types/domain'
import { formatRelative, initials } from '@/utils/format'

defineProps<{
  technicians: Technician[]
  selectedTechnicianId?: string | null
}>()

defineEmits<{
  (event: 'select', technicianId: string): void
  (event: 'select-proximity', technicianId: string): void
}>()
</script>

<template>
  <div v-if="technicians.length" class="order-list">
    <div v-for="tech in technicians" :key="tech.id" class="technician-card" :class="{ 'is-selected': tech.id === selectedTechnicianId }">
      <div class="technician-card__head">
        <span class="avatar" aria-hidden="true">{{ initials(tech.fullName) }}</span>
        <span class="grow">
          <span class="strong">{{ tech.fullName }}</span>
          <span class="text-xs muted" style="display: block">
            {{ tech.employeeCode ?? 'Sin código' }} ·
            {{ tech.vehicleLabel ?? 'Sin vehículo' }}
          </span>
        </span>
      </div>

      <div class="row row--between text-xs">
        <span class="muted">Carga vigente</span>
        <span class="strong">
          {{ tech.activeOrders }} / {{ tech.maxDailyOrders }}
        </span>
      </div>
      <div class="workload-bar" role="presentation">
        <div
          class="workload-bar__fill"
          :style="{
            width: `${Math.min(100, (tech.activeOrders / Math.max(1, tech.maxDailyOrders)) * 100)}%`,
          }"
        />
      </div>

      <div class="order-card__meta">
        <span>{{ tech.assignedOrders }} asignadas</span>
        <span>{{ tech.inProgressOrders }} en proceso</span>
      </div>

      <p class="text-xs muted">
        GPS: {{ formatRelative(tech.locationUpdatedAt) }}
        <template v-if="!tech.location"> · sin ubicación conocida</template>
      </p>

      <div class="row" style="gap: 6px">
        <button
          type="button"
          class="btn btn--sm btn--navy grow"
          @click="$emit('select', tech.id)"
        >
          Asignar órdenes
        </button>
        <button
          type="button"
          class="btn btn--sm btn--ghost"
          :disabled="!tech.location"
          title="Marcar órdenes cercanas a su última ubicación"
          @click="$emit('select-proximity', tech.id)"
        >
          Cercanas
        </button>
      </div>
    </div>
  </div>

  <div v-else class="order-list__empty">
    <p class="strong">No hay cuadrillas activas</p>
    <p class="text-sm muted">El seed no devolvió técnicos activos.</p>
  </div>
</template>
