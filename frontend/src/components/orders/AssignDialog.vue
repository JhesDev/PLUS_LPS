<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { WorkOrder } from '@/types/domain'
import type { Actor } from '@/services/operationsRepository'
import { useOperationsStore } from '@/stores/operations'
import { useToastStore } from '@/stores/toasts'
import StatusBadge from '@/components/common/StatusBadge.vue'

const props = defineProps<{
  open: boolean
  orders: WorkOrder[]
  actor: Actor
  preselectedTechnicianId?: string | null
}>()

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'assigned', payload: { technicianName: string; count: number }): void
}>()

const operations = useOperationsStore()
const toasts = useToastStore()

const technicianId = ref<string>(props.preselectedTechnicianId ?? '')
const notes = ref('')
const error = ref<string | null>(null)

watch(
  () => [props.open, props.preselectedTechnicianId],
  () => {
    if (props.open) {
      technicianId.value = props.preselectedTechnicianId ?? ''
      notes.value = ''
      error.value = null
    }
  },
  { immediate: true },
)

const selectedTechnician = computed(() =>
  operations.technicians.find((tech) => tech.id === technicianId.value) ?? null,
)

const reassignCount = computed(
  () =>
    props.orders.filter(
      (order) =>
        order.assignment && order.assignment.technicianId !== technicianId.value,
    ).length,
)

async function confirm(): Promise<void> {
  error.value = null
  if (!technicianId.value) {
    error.value = 'Selecciona un técnico destino.'
    return
  }
  if (!props.orders.length) {
    error.value = 'No hay órdenes seleccionadas.'
    return
  }

  try {
    const result = await operations.assignOrders({
      orderIds: props.orders.map((order) => order.id),
      technicianId: technicianId.value,
      actor: props.actor,
      notes: notes.value,
    })
    toasts.success(
      `${result.assigned} asignadas y ${result.reassigned} reasignadas a ${result.technicianName}.`,
    )
    emit('assigned', {
      technicianName: result.technicianName,
      count: result.assigned + result.reassigned,
    })
    emit('close')
  } catch (caught) {
    error.value =
      caught instanceof Error ? caught.message : 'No se pudo completar la asignación.'
  }
}
</script>

<template>
  <div v-if="open" class="modal-backdrop" role="presentation" @click.self="emit('close')">
    <div class="modal" role="dialog" aria-modal="true" aria-labelledby="assign-title">
      <div class="modal__head">
        <div>
          <h2 id="assign-title" class="modal__title">
            Asignar a cuadrilla
          </h2>
          <p class="text-sm muted">
            {{ orders.length }} orden(es) seleccionada(s)
          </p>
        </div>
        <button type="button" class="btn btn--sm btn--ghost" @click="emit('close')">
          Cerrar
        </button>
      </div>

      <div class="modal__body">
        <div class="field">
          <label for="assign-technician">Técnico destino</label>
          <select id="assign-technician" v-model="technicianId" class="select">
            <option value="">Selecciona un técnico…</option>
            <option
              v-for="tech in operations.technicians"
              :key="tech.id"
              :value="tech.id"
            >
              {{ tech.fullName }} · {{ tech.activeOrders }}/{{ tech.maxDailyOrders }}
            </option>
          </select>
        </div>

        <div v-if="selectedTechnician" class="card" style="padding: 10px">
          <p class="text-sm">
            <span class="strong">{{ selectedTechnician.fullName }}</span>
            <span class="muted">
              · {{ selectedTechnician.assignedOrders }} asignadas,
              {{ selectedTechnician.inProgressOrders }} en proceso
            </span>
          </p>
          <p class="text-xs muted">
            Capacidad diaria: {{ selectedTechnician.maxDailyOrders }} órdenes.
          </p>
        </div>

        <div class="field">
          <label for="assign-notes">Nota para la asignación (opcional)</label>
          <textarea id="assign-notes" v-model="notes" class="textarea" rows="2" />
        </div>

        <div v-if="reassignCount" class="alert alert--warning">
          {{ reassignCount }} orden(es) ya tienen asignación vigente y se
          reasignarán; la asignación anterior quedará cerrada con motivo
          <em>reasignada</em>.
        </div>

        <div class="stack stack--tight">
          <p class="field-label">Órdenes en el lote</p>
          <ul class="assign-list">
            <li v-for="order in orders.slice(0, 12)" :key="order.id">
              <span class="mono strong">{{ order.code }}</span>
              <span class="grow">{{ order.customerName ?? '—' }}</span>
              <StatusBadge :status="order.status" />
            </li>
          </ul>
          <p v-if="orders.length > 12" class="text-xs muted">
            y {{ orders.length - 12 }} más…
          </p>
        </div>

        <p v-if="error" class="alert alert--error">{{ error }}</p>

        <p class="alert alert--info">
          Se ejecuta sobre datos demo locales con la misma semántica que la RPC
          <code class="mono">assign_work_order</code>: una sola asignación vigente por
          orden.
        </p>
      </div>

      <div class="modal__footer">
        <button type="button" class="btn btn--ghost" @click="emit('close')">
          Cancelar
        </button>
        <button
          type="button"
          class="btn btn--primary"
          :disabled="operations.busy || !technicianId"
          @click="confirm"
        >
          {{ operations.busy ? 'Asignando…' : 'Confirmar asignación' }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.assign-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 4px;
  max-height: 190px;
  overflow-y: auto;
}

.assign-list li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 5px 8px;
  border: 1px solid var(--ink-200);
  border-radius: var(--radius-sm);
  font-size: 12.5px;
}
</style>
