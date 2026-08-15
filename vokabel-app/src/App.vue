<template>
  <div class="app">
    <header>
      <button
        class="theme-toggle"
        type="button"
        @click="cycleTheme"
        :title="themeLabel"
      >{{ themeIcon }} {{ themeLabel }}</button>
      <h1>🎓 Vokabeltrainer</h1>
      <div class="cloud-toggle-row">
        <label class="cloud-toggle-label" title="Use Gemini only for AI features">
          <input type="checkbox" v-model="cloudModelsOnly" />
          Cloud models only (Gemini)
        </label>
      </div>
      <div class="llm-selector">
        <span class="llm-icon">🤖</span>
        <select
          v-model="selectedModel"
          @change="switchModel"
          class="model-select"
          :disabled="cloudModelsOnly || modelSwitching || availableModels.length === 0"
          :title="modelSwitching ? 'Switching model…' : 'Select LLM model'"
        >
          <option v-if="availableModels.length === 0" value="">No models found</option>
          <option v-for="m in availableModels" :key="m" :value="m">{{ m }}</option>
        </select>
        <span v-if="modelSwitching" class="switching-indicator">⏳</span>
      </div>
    </header>
    
    <div class="tabs">
      <button 
        class="tab-button" 
        :class="{ active: activeTab === 'translator' }"
        @click="activeTab = 'translator'"
      >
        Translator
      </button>
      <button 
        class="tab-button" 
        :class="{ active: activeTab === 'vocabulary' }"
        @click="activeTab = 'vocabulary'"
      >
        Vocabulary Testing
      </button>
      <button 
        class="tab-button" 
        :class="{ active: activeTab === 'wordlists' }"
        @click="activeTab = 'wordlists'"
      >
        Word Lists
      </button>
      <button 
        class="tab-button" 
        :class="{ active: activeTab === 'writing' }"
        @click="activeTab = 'writing'"
      >
        Writing Practice
      </button>
    </div>

    <div class="tab-content">
      <TranslatorTab v-if="activeTab === 'translator'" :cloud-models-only="cloudModelsOnly" />
      <VocabularyTab v-if="activeTab === 'vocabulary'" :cloud-models-only="cloudModelsOnly" />
      <WordListsTab v-if="activeTab === 'wordlists'" />
      <TextEvaluationTab v-if="activeTab === 'writing'" :cloud-models-only="cloudModelsOnly" />
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue'
import TranslatorTab from './components/TranslatorTab.vue'
import VocabularyTab from './components/VocabularyTab.vue'
import WordListsTab from './components/WordListsTab.vue'
import TextEvaluationTab from './components/TextEvaluationTab.vue'

export default {
  name: 'App',
  components: {
    TranslatorTab,
    VocabularyTab,
    WordListsTab,
    TextEvaluationTab
  },
  setup() {
    const activeTab = ref('translator')
    const availableModels = ref([])
    const selectedModel = ref('')
    const modelSwitching = ref(false)
    const cloudModelsOnly = ref(localStorage.getItem('cloudModelsOnly') === 'true')

    // Theme: 'system' | 'light' | 'dark'. 'system' means no data-theme attribute at all,
    // so the prefers-color-scheme media query in style.css decides.
    const THEME_CYCLE = ['system', 'light', 'dark']
    const theme = ref(localStorage.getItem('theme') || 'system')

    const applyTheme = (value) => {
      if (value === 'system') {
        document.documentElement.removeAttribute('data-theme')
      } else {
        document.documentElement.setAttribute('data-theme', value)
      }
    }
    applyTheme(theme.value)

    const cycleTheme = () => {
      const next = THEME_CYCLE[(THEME_CYCLE.indexOf(theme.value) + 1) % THEME_CYCLE.length]
      theme.value = next
      localStorage.setItem('theme', next)
      applyTheme(next)
    }

    const themeIcon = computed(() => ({ system: '🖥️', light: '☀️', dark: '🌙' }[theme.value]))
    const themeLabel = computed(() => ({ system: 'System', light: 'Light', dark: 'Dark' }[theme.value]))

    const PREFERRED_DEFAULT = 'gemma4:e2b'

    onMounted(async () => {  
      try {
        const res = await fetch('/api/ollama_models')
        const data = await res.json()
        availableModels.value = data.models || []

        // Pick default: preferred > server-reported current > first in list
        const current = data.current
        if (availableModels.value.includes(PREFERRED_DEFAULT)) {
          selectedModel.value = PREFERRED_DEFAULT
        } else if (current && availableModels.value.includes(current)) {
          selectedModel.value = current
        } else if (availableModels.value.length > 0) {
          selectedModel.value = availableModels.value[0]
        }
      } catch {
        availableModels.value = []
      }
    })

    const switchModel = async () => {
      if (!selectedModel.value || modelSwitching.value) return
      modelSwitching.value = true
      try {
        await fetch(`/api/switch_model?model_id=${encodeURIComponent(selectedModel.value)}`, {
          method: 'POST'
        })
      } catch { /* ignore */ } finally {
        modelSwitching.value = false
      }
    }

    watch(cloudModelsOnly, (value) => {
      localStorage.setItem('cloudModelsOnly', value ? 'true' : 'false')
    })

    return {
      activeTab,
      availableModels,
      selectedModel,
      modelSwitching,
      cloudModelsOnly,
      switchModel,
      theme,
      cycleTheme,
      themeIcon,
      themeLabel,
    }
  }
}
</script>

<style scoped>
.app {
  min-height: 100vh;
}

header {
  position: relative;
  background: linear-gradient(135deg, var(--brand-1) 0%, var(--brand-2) 100%);
  color: white;
  padding: 2rem;
  text-align: center;
  box-shadow: 0 4px 6px rgba(var(--shadow-color), 0.1);
}

.theme-toggle {
  position: absolute;
  top: 1rem;
  right: 1rem;
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.45);
  border-radius: 20px;
  padding: 0.35rem 0.85rem;
  font-size: 0.8rem;
  font-weight: 600;
  color: white;
  cursor: pointer;
  transition: background 0.15s;
}

.theme-toggle:hover {
  background: rgba(255, 255, 255, 0.25);
}

header h1 {
  margin: 0;
  font-size: 2.5rem;
  font-weight: 600;
}

.llm-selector {
  margin-top: 0.5rem;
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
}

.cloud-toggle-row {
  margin-top: 0.85rem;
}

.cloud-toggle-label {
  display: inline-flex;
  gap: 0.45rem;
  align-items: center;
  font-size: 0.9rem;
  font-weight: 600;
}

.llm-icon {
  font-size: 0.95rem;
}

.model-select {
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.45);
  border-radius: 20px;
  padding: 0.25rem 0.75rem;
  font-size: 0.83rem;
  font-weight: 500;
  color: white;
  cursor: pointer;
  max-width: 220px;
  transition: background 0.15s;
}

.model-select:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.25);
}

.model-select:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.model-select option {
  background: #3a3a5c;
  color: white;
}

.switching-indicator {
  font-size: 0.85rem;
}

.tabs {
  display: flex;
  justify-content: center;
  gap: 1rem;
  padding: 2rem 1rem 0;
  background-color: var(--bg-page);
}

.tab-button {
  padding: 0.75rem 2rem;
  font-size: 1.1rem;
  font-weight: 500;
  border: none;
  background-color: var(--bg-surface);
  color: var(--brand-1);
  border-radius: 8px 8px 0 0;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 2px 4px rgba(var(--shadow-color), 0.1);
}

.tab-button:hover {
  background-color: var(--bg-tint);
  transform: translateY(-2px);
}

.tab-button.active {
  background: linear-gradient(135deg, var(--brand-1) 0%, var(--brand-2) 100%);
  color: white;
  box-shadow: 0 4px 6px rgba(var(--shadow-color), 0.15);
}

.tab-content {
  background-color: var(--bg-page);
  min-height: calc(100vh - 200px);
  padding: 2rem;
}
</style>
