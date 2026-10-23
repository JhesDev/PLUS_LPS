<script setup lang="ts">
import { computed } from 'vue'
import { PRIORITY_META } from '@/utils/status'

const props = defineProps<{ priority: number }>()
const meta = computed(
  () => PRIORITY_META[props.priority] ?? { label: `P${props.priority}`, color: '#64748b' },
)
</script>

<template>
  <span
    class="tag"
    :style="{ background: `${meta.color}1a`, color: meta.color }"
    :title="`Criticidad ${meta.label}`"
  >
    {{ meta.label }}
  </span>
</template>
