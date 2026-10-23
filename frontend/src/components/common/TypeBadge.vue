<script setup lang="ts">
import { computed } from 'vue'
import type { WorkOrderType } from '@/types/domain'
import { TYPE_META } from '@/utils/status'
import TypeIcon from './TypeIcon.vue'

const props = defineProps<{ type: WorkOrderType }>()
const meta = computed(() => TYPE_META[props.type])
</script>

<template>
  <span class="tag" :style="{ background: '#eef2f6', color: '#334155' }">
    <TypeIcon :type="type" :size="13" />
    {{ meta.label }}
  </span>
</template>
