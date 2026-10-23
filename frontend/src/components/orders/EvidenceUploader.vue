<script setup lang="ts">
import { ref } from 'vue'
import type { EvidenceKind } from '@/types/domain'
import type { Actor } from '@/services/operationsRepository'
import { useOperationsStore } from '@/stores/operations'
import { useToastStore } from '@/stores/toasts'
import { EVIDENCE_KIND_META } from '@/utils/status'

const props = defineProps<{ orderId: string; actor: Actor }>()

const operations = useOperationsStore()
const toasts = useToastStore()

const kind = ref<EvidenceKind>('durante')
const dragover = ref(false)
const uploading = ref(false)
const error = ref<string | null>(null)

const KINDS: EvidenceKind[] = ['antes', 'durante', 'despues', 'firma', 'documento', 'otro']

async function handleFiles(files: FileList | null): Promise<void> {
  if (!files?.length) return
  error.value = null
  uploading.value = true
  try {
    for (const file of Array.from(files)) {
      await operations.addEvidence({
        orderId: props.orderId,
        kind: kind.value,
        file,
        actor: props.actor,
      })
    }
    toasts.success(
      'Evidencia registrada como demo local. La subida a Storage queda pendiente de integración.',
    )
  } catch (caught) {
    error.value =
      caught instanceof Error ? caught.message : 'No se pudo registrar la evidencia.'
    toasts.error(error.value)
  } finally {
    uploading.value = false
  }
}

function onDrop(event: DragEvent): void {
  dragover.value = false
  void handleFiles(event.dataTransfer?.files ?? null)
}

function onPick(event: Event): void {
  const input = event.target as HTMLInputElement
  void handleFiles(input.files)
  input.value = ''
}
</script>

<template>
  <div class="stack stack--tight">
    <div class="field">
      <label for="evidence-kind">Tipo de evidencia</label>
      <select id="evidence-kind" v-model="kind" class="select" :disabled="uploading">
        <option v-for="item in KINDS" :key="item" :value="item">
          {{ EVIDENCE_KIND_META[item] }}
        </option>
      </select>
    </div>

    <label
      class="dropzone"
      :class="{ 'is-dragover': dragover }"
      for="evidence-file"
      @dragover.prevent="dragover = true"
      @dragleave.prevent="dragover = false"
      @drop.prevent="onDrop"
    >
      <span class="strong">
        {{ uploading ? 'Procesando…' : 'Arrastra una imagen o PDF aquí' }}
      </span>
      <span class="text-xs">
        JPEG, PNG, WEBP o PDF · máximo 10 MiB (límite del bucket)
      </span>
      <input
        id="evidence-file"
        class="visually-hidden"
        type="file"
        accept="image/jpeg,image/png,image/webp,application/pdf"
        multiple
        :disabled="uploading"
        @change="onPick"
      />
    </label>

    <p v-if="error" class="alert alert--error">{{ error }}</p>

    <p class="alert alert--warning">
      Boceto: la imagen se registra solo como previsualización local. No se sube a
      Supabase Storage ni a la API hasta que exista el flujo de integración.
    </p>
  </div>
</template>
