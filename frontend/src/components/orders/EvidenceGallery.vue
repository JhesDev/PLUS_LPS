<script setup lang="ts">
import type { Evidence } from '@/types/domain'
import { EVIDENCE_KIND_META } from '@/utils/status'
import { formatBytes, formatDateTime } from '@/utils/format'

defineProps<{ evidence: Evidence[]; readOnly?: boolean }>()

const emit = defineEmits<{ (event: 'preview', item: Evidence): void }>()
</script>

<template>
  <div v-if="evidence.length" class="evidence-grid">
    <figure v-for="item in evidence" :key="item.id" class="evidence-tile">
      <button
        type="button"
        class="evidence-tile__thumb"
        :title="`Ver ${EVIDENCE_KIND_META[item.kind]}`"
        @click="emit('preview', item)"
      >
        <img
          v-if="item.localPreviewUrl"
          :src="item.localPreviewUrl"
          :alt="`Evidencia ${EVIDENCE_KIND_META[item.kind]}`"
        />
        <template v-else>
          <span>
            {{ EVIDENCE_KIND_META[item.kind] }}
            <br />
            metadatos demo
          </span>
        </template>
      </button>
      <figcaption class="evidence-tile__meta">
        <span class="strong">{{ EVIDENCE_KIND_META[item.kind] }}</span>
        <span>{{ formatBytes(item.sizeBytes) }}</span>
        <span>{{ formatDateTime(item.capturedAt) }}</span>
      </figcaption>
    </figure>
  </div>

  <p v-else class="text-sm muted">
    Sin evidencias registradas.
    <template v-if="!readOnly">
      Las imágenes se suben al bucket privado
      <code class="mono">work-order-evidence</code>.
    </template>
  </p>
</template>
