<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/layout/AppHeader.vue'
import ToastHost from '@/components/common/ToastHost.vue'
import { useOperationsStore } from '@/stores/operations'
import { useSessionStore } from '@/stores/session'

const route = useRoute()
const operations = useOperationsStore()
const session = useSessionStore()

const showChrome = computed(
  () => route.meta.public !== true && session.isReady,
)

const metrics = computed(() =>
  route.name !== 'tecnico' && operations.orders.length
    ? operations.globalMetrics
    : null,
)
</script>

<template>
  <div class="app-shell" :class="{ 'app-shell--public': !showChrome }">
    <AppHeader v-if="showChrome" :metrics="metrics" />
    <main class="app-main">
      <RouterView />
    </main>
    <ToastHost />
  </div>
</template>

<style scoped>
.app-shell--public {
  grid-template-rows: 1fr;
}
</style>
