<script setup lang="ts">
import { DEMO_DATA_DETAIL, DEMO_DATA_LABEL } from '@/config/dataSource'

withDefaults(defineProps<{ compact?: boolean }>(), { compact: false })
</script>

<template>
  <span class="source-badge" :title="DEMO_DATA_DETAIL">
    <span class="source-badge__dot" aria-hidden="true" />
    {{ compact ? 'Demo' : DEMO_DATA_LABEL }}
  </span>
</template>
