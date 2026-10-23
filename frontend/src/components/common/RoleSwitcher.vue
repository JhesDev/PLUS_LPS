<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { DEMO_USERS, useSessionStore } from '@/stores/session'
import { roleHome } from '@/router'

const session = useSessionStore()
const router = useRouter()
const open = ref(false)

const label = computed(() => `${session.actor.name} · ${session.role}`)

async function choose(userId: string): Promise<void> {
  session.setActor(userId)
  open.value = false
  const target = roleHome(session.role ?? 'despachador')
  if (router.currentRoute.value.path !== target) await router.push(target)
}
</script>

<template>
  <div class="role-switcher">
    <button
      type="button"
      class="role-switcher__trigger"
      :aria-expanded="open"
      @click="open = !open"
    >
      <span class="role-switcher__name">{{ label }}</span>
      <span class="role-switcher__caret" aria-hidden="true">▾</span>
    </button>

    <div v-if="open" class="role-switcher__menu" role="menu">
      <p class="role-switcher__note">
        Simulación de sesión. El rol real lo resuelve el backend desde
        <code>public.profiles</code>.
      </p>
      <button
        v-for="user in DEMO_USERS"
        :key="user.id"
        type="button"
        class="role-switcher__item"
        :class="{ 'is-active': user.id === session.actorId }"
        role="menuitem"
        @click="choose(user.id)"
      >
        <span>{{ user.name }}</span>
        <span class="text-xs muted">{{ user.role }}</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.role-switcher {
  position: relative;
}

.role-switcher__trigger {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.24);
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
  font-weight: 600;
  font-size: 12.5px;
}

.role-switcher__trigger:hover {
  background: rgba(255, 255, 255, 0.16);
}

.role-switcher__menu {
  position: absolute;
  right: 0;
  top: calc(100% + 8px);
  width: 258px;
  background: var(--surface);
  color: var(--ink-900);
  border-radius: var(--radius);
  box-shadow: var(--shadow-lg);
  padding: 8px;
  display: grid;
  gap: 3px;
  z-index: 60;
}

.role-switcher__note {
  font-size: 11px;
  color: var(--ink-500);
  padding: 4px 6px 8px;
  border-bottom: 1px solid var(--ink-200);
  margin-bottom: 4px;
}

.role-switcher__note code {
  font-family: var(--font-mono);
}

.role-switcher__item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 8px 9px;
  border: 0;
  border-radius: var(--radius-sm);
  background: transparent;
  text-align: left;
  font-weight: 600;
  font-size: 13px;
}

.role-switcher__item:hover {
  background: var(--ink-100);
}

.role-switcher__item.is-active {
  background: var(--accent-100);
  color: var(--accent-600);
}
</style>
