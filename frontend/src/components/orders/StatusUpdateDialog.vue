<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { WorkOrder, WorkOrderStatus } from '@/types/domain'
import type { Actor } from '@/services/operationsRepository'
import { useOperationsStore } from '@/stores/operations'
import { useToastStore } from '@/stores/toasts'
import StatusBadge from '@/components/common/StatusBadge.vue'
import { STATUS_META, allowedTransitions, requiresReason } from '@/utils/status'

const props = defineProps<{
  open: boolean
  order: WorkOrder
  actor: Actor
  /** Estado destino sugerido al abrir (p. ej. en_proceso desde la card). */
  suggestedStatus?: WorkOrderStatus | null
}>()

const emit = defineEmits<{ (event: 'close'): void }>()

const operations = useOperationsStore()
const toasts = useToastStore()

const target = ref<WorkOrderStatus | ''>('')
const reason = ref('')
const error = ref<string | null>(null)

const allowed = computed(() =>
  allowedTransitions(props.actor.role, props.order.status),
)

watch(
  () => [props.open, props.order.id],
  () => {
    if (!props.open) return
    const options = allowed.value
    target.value =
      props.suggestedStatus && options.includes(props.suggestedStatus)
        ? props.suggestedStatus
        : (options[0] ?? '')
    reason.value = ''
    error.value = null
  },
  { immediate: true },
)

const reasonRequired = computed(() =>
  target.value ? requiresReason(target.value as WorkOrderStatus) : false,
)

async function confirm(): Promise<void> {
  error.value = null
  if (!target.value) {
    error.value = 'Selecciona el estado destino.'
    return
  }
  if (reasonRequired.value && !reason.value.trim()) {
    error.value = `El estado ${STATUS_META[target.value as WorkOrderStatus].label} requiere un motivo.`
    return
  }

  try {
    await operations.updateStatus({
      orderId: props.order.id,
      status: target.value as WorkOrderStatus,
      actor: props.actor,
      reason: reason.value,
      location: props.order.location,
    })
    toasts.success(
      `${props.order.code} → ${STATUS_META[target.value as WorkOrderStatus].label}.`,
    )
    emit('close')
  } catch (caught) {
    error.value =
      caught instanceof Error ? caught.message : 'No se pudo actualizar el estado.'
  }
}
</script>

<template>
  <div v-if="open" class="modal-backdrop" role="presentation" @click.self="emit('close')">
    <div class="modal" role="dialog" aria-modal="true" aria-labelledby="status-title">
      <div class="modal__head">
        <div>
          <h2 id="status-title" class="modal__title">Cambiar estado</h2>
          <p class="text-sm muted row" style="gap: 6px">
            <span class="mono strong">{{ order.code }}</span>
            <StatusBadge :status="order.status" />
          </p>
        </div>
        <button type="button" class="btn btn--sm btn--ghost" @click="emit('close')">
          Cerrar
        </button>
      </div>

      <div class="modal__body">
        <div v-if="allowed.length" class="field">
          <label for="status-target">Estado destino</label>
          <select id="status-target" v-model="target" class="select">
            <option v-for="status in allowed" :key="status" :value="status">
              {{ STATUS_META[status].label }}
            </option>
          </select>
        </div>

        <p v-else class="alert alert--info">
          El rol {{ actor.role }} no tiene transiciones disponibles desde
          {{ STATUS_META[order.status].label }}.
        </p>

        <div class="field">
          <label for="status-reason">
            Motivo
            <span v-if="reasonRequired" class="muted">(obligatorio)</span>
          </label>
          <textarea
            id="status-reason"
            v-model="reason"
            class="textarea"
            rows="2"
            :placeholder="reasonRequired ? 'Describe el motivo' : 'Opcional'"
          />
        </div>

        <p v-if="error" class="alert alert--error">{{ error }}</p>

        <p class="alert alert--info">
          Se registra el historial de auditoría con actor, fecha y motivo, igual
          que <code class="mono">update_work_order_status</code>.
        </p>
      </div>

      <div class="modal__footer">
        <button type="button" class="btn btn--ghost" @click="emit('close')">
          Cancelar
        </button>
        <button
          type="button"
          class="btn btn--primary"
          :disabled="operations.busy || !allowed.length"
          @click="confirm"
        >
          {{ operations.busy ? 'Guardando…' : 'Aplicar cambio' }}
        </button>
      </div>
    </div>
  </div>
</template>
