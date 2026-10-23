<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useSessionStore } from '@/stores/session'
import { useToastStore } from '@/stores/toasts'
import { ROLE_NAV } from '@/config/runtime'
import type { OperationMetrics } from '@/utils/metrics'
import KpiStrip from '@/components/common/KpiStrip.vue'
import RoleSwitcher from '@/components/common/RoleSwitcher.vue'

withDefaults(defineProps<{ metrics?: OperationMetrics | null }>(), {
  metrics: null,
})

const session = useSessionStore()
const toasts = useToastStore()
const router = useRouter()
const emit = defineEmits<{ (event: 'sync-requested'): void }>()

const roleLabel = computed(() => {
  if (session.role === 'coordinador') return 'Coordinador'
  if (session.role === 'despachador') return 'Despachador'
  if (session.role === 'tecnico') return 'Técnico'
  return ''
})

function requestSync(): void {
  emit('sync-requested')
  toasts.info(
    'Sincronización con SAP pendiente: el backend responde 503 INTEGRATION_PENDING hasta que exista contrato oficial. No se ejecuta ninguna llamada.',
  )
}

function explainPending(): void {
  toasts.info(
    'Sincronización con SAP pendiente: el backend responde 503 INTEGRATION_PENDING hasta que exista contrato oficial. No se ejecuta ninguna llamada.',
  )
}

async function handleLogout(): Promise<void> {
  try {
    if (session.isDemo) {
      session.leaveDemo()
    } else {
      await session.signOut()
    }
    await router.replace('/login')
  } catch (err) {
    toasts.error(err instanceof Error ? err.message : 'No se pudo cerrar sesión.')
  }
}
</script>

<template>
  <header class="app-header">
    <div class="brand">
      <span class="brand__logo" aria-hidden="true">LPS</span>
      <span>
        <span class="brand__name">Grupo LPS · PLUZ</span>
        <span class="brand__sub">Panel operativo de campo</span>
      </span>
    </div>

    <nav class="app-nav" aria-label="Vistas del boceto">
      <RouterLink
        v-for="item in ROLE_NAV"
        :key="item.role"
        class="app-nav__item"
        :to="item.path"
        :title="item.description"
      >
        {{ item.label }}
      </RouterLink>
    </nav>

    <div class="app-header__kpis">
      <KpiStrip v-if="metrics" :metrics="metrics" />
    </div>

    <div class="app-header__spacer" />

    <div class="app-header__actions">
      <button
        v-if="session.isDispatcher"
        type="button"
        class="btn btn--sm btn--ghost sync-btn"
        title="Sincronizar con SAP (integración pendiente de contrato)"
        @click="requestSync"
      >
        ⟳ Sincronizar ahora
        <span class="sync-btn__flag">pendiente</span>
      </button>

      <button
        v-else
        type="button"
        class="btn btn--sm btn--ghost sync-btn"
        title="El rol actual no puede disparar la sincronización"
        @click="explainPending"
      >
        ⟳ Sync SAP
        <span class="sync-btn__flag">pendiente</span>
      </button>

      <RoleSwitcher v-if="session.isDemo" />

      <!-- Usuario activo + logout -->
      <div class="user-chip">
        <span class="user-chip__name" :title="session.email ?? session.actor.name">
          {{ session.actor.name }}
        </span>
        <span v-if="roleLabel" class="user-chip__role">{{ roleLabel }}</span>
        <button
          type="button"
          class="btn btn--sm btn--ghost logout-btn"
          title="Cerrar sesión"
          @click="handleLogout"
        >
          ⇥ Salir
        </button>
      </div>
    </div>
  </header>
</template>

<style scoped>
.sync-btn {
  color: #dbe9f4;
  border-color: rgba(255, 255, 255, 0.24);
  background: rgba(255, 255, 255, 0.06);
}

.sync-btn:hover {
  background: rgba(255, 255, 255, 0.14);
}

.sync-btn__flag {
  font-size: 10px;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 999px;
  background: var(--warning);
  color: #3f2a02;
}

.app-header__kpis {
  margin-left: 12px;
  min-width: 0;
  overflow: hidden;
}

.user-chip {
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 20px;
  padding: 3px 10px 3px 10px;
  max-width: 260px;
}

.user-chip__name {
  font-size: 12px;
  font-weight: 600;
  color: #e2eaf3;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 120px;
}

.user-chip__role {
  font-size: 10px;
  font-weight: 700;
  padding: 1px 6px;
  border-radius: 999px;
  background: rgba(255,255,255,0.18);
  color: #c7d8ea;
  white-space: nowrap;
}

.logout-btn {
  color: #dbe9f4;
  border-color: transparent;
  background: transparent;
  padding: 2px 6px;
  font-size: 12px;
}

.logout-btn:hover {
  background: rgba(220, 38, 38, 0.3);
  color: #fca5a5;
}

@media (max-width: 1240px) {
  .app-header__kpis {
    display: none;
  }
}

@media (max-width: 900px) {
  .sync-btn {
    display: none;
  }

  .user-chip__name {
    max-width: 80px;
  }
}
</style>
