<script setup lang="ts">
import { computed } from 'vue'
import type { WorkOrderStatus } from '@/types/domain'
import { STATUS_META } from '@/utils/status'

const props = withDefaults(
  defineProps<{
    status: WorkOrderStatus
    outline?: boolean
  }>(),
  { outline: false },
)

const meta = computed(() => STATUS_META[props.status])
</script>

<template>
  <span
    class="tag"
    :class="{ 'tag--outline': outline }"
    :style="{
      background: outline ? 'transparent' : meta.soft,
      color: outline ? meta.color : meta.color,
    }"
    :title="meta.description"
  >
    <span
      class="tag__dot"
      :style="{ background: meta.color }"
      aria-hidden="true"
    />
    {{ meta.label }}
  </span>
</template>

<style scoped>
.tag__dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
}
</style>
