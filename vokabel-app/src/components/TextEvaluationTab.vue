<template>
  <div class="text-eval-tab">

    <!-- ── Setup panel ───────────────────────────────────────────────── -->
    <div v-if="!sessionStarted" class="setup-panel">
      <h2>✍️ Writing Practice</h2>
      <p class="subtitle">
        Get a set of words sampled from your vocabulary and write a text that uses them.
        Gemini AI will give you instant feedback.
      </p>

      <div class="form-grid">

        <!-- Language -->
        <div class="form-group">
          <label>Practice Language:</label>
          <div class="language-selector">
            <img :src="`/${practiceLanguage}.png`" :alt="practiceLanguage" class="flag-icon" />
            <select v-model="practiceLanguage" @change="onLanguageChange" class="language-select">
              <option value="english">English</option>
              <option value="german">German</option>
              <option value="spanish">Spanish</option>
              <option value="french">French</option>
            </select>
          </div>
        </div>

        <!-- Level -->
        <div class="form-group">
          <label>Feedback level:</label>
          <select v-model="level" class="language-select">
            <option value="Basic">Basic</option>
            <option value="Intermediate">Intermediate</option>
            <option value="Advanced">Advanced</option>
          </select>
        </div>

        <!-- Number of words -->
        <div class="form-group">
          <label>Words per task:</label>
          <input type="number" v-model.number="noWords" class="text-input" min="1" max="10" />
        </div>

        <!-- Description filter -->
        <div class="form-group">
          <label>Word filter description <span class="optional">(optional)</span>:</label>
          <input type="text" v-model="description" class="text-input" placeholder="e.g. verbs only, nouns only" />
        </div>

        <!-- Date range -->
        <div class="form-group">
          <label>Start date <span class="optional">(optional)</span>:</label>
          <div class="date-input-row">
            <input type="date" v-model="startDate" class="text-input" />
            <button @click="startDate = ''" class="clear-btn" type="button" title="Clear">✕</button>
          </div>
        </div>

        <div class="form-group">
          <label>End date <span class="optional">(optional)</span>:</label>
          <div class="date-input-row">
            <input type="date" v-model="endDate" class="text-input" />
            <button @click="endDate = ''" class="clear-btn" type="button" title="Clear">✕</button>
          </div>
        </div>

        <!-- Tag filter (full width) -->
        <div class="form-group tag-filter-group">
          <div class="tag-filter-header">
            <label>Filter by Tags:</label>
            <div class="tag-filter-controls">
              <div class="tag-control-pair">
                <span class="tag-control-label">Mode</span>
                <div class="tag-mode-buttons">
                  <button @click="tagFilterMode = 'include'" :class="['tag-mode-btn', { active: tagFilterMode === 'include' }]" type="button">Include</button>
                  <button @click="tagFilterMode = 'exclude'" :class="['tag-mode-btn', { active: tagFilterMode === 'exclude' }]" type="button">Exclude</button>
                </div>
              </div>
              <div class="tag-control-pair">
                <span class="tag-control-label">Match</span>
                <div class="tag-mode-buttons">
                  <button @click="tagMatchMode = 'any'" :class="['tag-mode-btn', { active: tagMatchMode === 'any' }]" type="button" title="Words with at least one tag">Any tag</button>
                  <button @click="tagMatchMode = 'all'" :class="['tag-mode-btn', { active: tagMatchMode === 'all' }]" type="button" title="Words that have all tags">All tags</button>
                </div>
              </div>
              <button @click="selectedTags = []" class="ignore-tags-btn" type="button">🏷️ Ignore tags</button>
            </div>
          </div>
          <div v-if="availableTags.length > 0" class="test-tag-chips">
            <button
              v-for="tag in availableTags"
              :key="tag"
              @click="toggleTag(tag)"
              :class="['test-tag-chip', { selected: selectedTags.includes(tag) }]"
              type="button"
            >{{ tag }}</button>
          </div>
          <div v-else class="no-tags-hint">No tags in this word list</div>
          <div v-if="selectedTags.length > 0" class="tag-filter-summary">
            <span v-if="tagFilterMode === 'include' && tagMatchMode === 'any'">Words with <strong>any of:</strong></span>
            <span v-else-if="tagFilterMode === 'include' && tagMatchMode === 'all'">Words with <strong>all of:</strong></span>
            <span v-else-if="tagFilterMode === 'exclude' && tagMatchMode === 'any'">Excluding words with <strong>any of:</strong></span>
            <span v-else>Excluding words that have <strong>all of:</strong></span>
            <strong>{{ selectedTags.join(', ') }}</strong>
          </div>
        </div>

      </div>

      <div v-if="setupError" class="error-banner">{{ setupError }}</div>

      <button @click="startSession" class="start-btn" :disabled="setupLoading">
        <span v-if="setupLoading">⏳ Starting…</span>
        <span v-else>▶ Start Writing Practice</span>
      </button>
    </div>

    <!-- ── Active session ────────────────────────────────────────────── -->
    <div v-else class="session-panel">

      <div class="session-header">
        <h2>✍️ Writing Practice</h2>
        <button @click="endSession" class="end-btn" type="button">✕ End Session</button>
      </div>

      <!-- Word prompt card -->
      <div class="prompt-card">
        <div class="prompt-label">Write a text in <strong>{{ practiceLanguage }}</strong> that uses:</div>
        <div class="word-chips">
          <span v-for="w in currentWords" :key="w" class="word-chip">{{ w }}</span>
        </div>
        <div class="round-badge">Round {{ round }}</div>
      </div>

      <!-- Text input area -->
      <div class="write-area">
        <textarea
          v-model="userText"
          ref="textareaRef"
          class="writing-textarea"
          :placeholder="`Write your ${practiceLanguage} text here…`"
          rows="6"
          :disabled="submitting"
          @keydown.ctrl.enter.prevent="submitText"
          @keydown.meta.enter.prevent="submitText"
        ></textarea>
        <div class="textarea-hint">Ctrl+Enter to submit</div>
      </div>

      <div class="submit-row">
        <button @click="nextRound" class="next-btn" type="button" :disabled="loadingNextWords">
          {{ loadingNextWords ? '⏳' : '⏭ Next words' }}
        </button>
        <button @click="submitText" class="submit-btn" type="button" :disabled="!userText.trim() || submitting">
          <span v-if="submitting">⏳ Evaluating…</span>
          <span v-else>✔ Submit</span>
        </button>
      </div>

      <!-- Feedback card -->
      <transition name="fade-slide">
        <div v-if="feedback" class="feedback-card" :class="{ 'no-mistakes': feedbackIsClean }">
          <div class="feedback-header">
            <span v-if="feedbackIsClean" class="feedback-icon">🎉</span>
            <span v-else class="feedback-icon">📝</span>
            <span class="feedback-title">{{ feedbackIsClean ? 'Great job!' : 'Feedback' }}</span>
            <span class="level-badge">{{ level }}</span>
          </div>
          <div class="feedback-body" v-html="formattedFeedback"></div>
        </div>
      </transition>

      <div v-if="sessionError" class="error-banner">{{ sessionError }}</div>

    </div>
  </div>
</template>

<script>
import { ref, computed, nextTick, watch } from 'vue'
import axios from 'axios'

export default {
  name: 'TextEvaluationTab',
  setup() {
    // Setup state
    const practiceLanguage = ref('english')
    const level = ref('Intermediate')
    const noWords = ref(2)
    const description = ref('')
    const startDate = ref('')
    const endDate = ref('')
    const tagFilterMode = ref('include')
    const tagMatchMode = ref('any')
    const selectedTags = ref([])
    const availableTags = ref([])
    const primaryLanguage = ref('german')
    const setupError = ref('')
    const setupLoading = ref(false)

    // Session state
    const sessionStarted = ref(false)
    const round = ref(1)
    const currentWords = ref([])
    const userText = ref('')
    const feedback = ref('')
    const submitting = ref(false)
    const loadingNextWords = ref(false)
    const sessionError = ref('')
    const textareaRef = ref(null)

    // ── Init ──────────────────────────────────────────────────────────
    const fetchPrimaryLanguage = async () => {
      try {
        const res = await axios.get('/api/primary_language')
        primaryLanguage.value = res.data.primary_language || 'german'
      } catch { /* keep default */ }
    }

    const fetchTags = async () => {
      availableTags.value = []
      try {
        const res = await axios.get('/api/tags', {
          params: { language_1: primaryLanguage.value, language_2: practiceLanguage.value }
        })
        availableTags.value = res.data.tags || []
        // drop selected tags that no longer exist
        selectedTags.value = selectedTags.value.filter(t => availableTags.value.includes(t))
      } catch { /* ignore */ }
    }

    const onLanguageChange = () => {
      selectedTags.value = []
      fetchTags()
    }

    fetchPrimaryLanguage().then(fetchTags)
    watch(practiceLanguage, fetchTags)

    // ── Helpers ───────────────────────────────────────────────────────
    const toggleTag = (tag) => {
      const idx = selectedTags.value.indexOf(tag)
      if (idx === -1) selectedTags.value.push(tag)
      else selectedTags.value.splice(idx, 1)
    }

    const feedbackIsClean = computed(() =>
      feedback.value.toLowerCase().startsWith('no mistakes')
    )

    const formattedFeedback = computed(() => {
      // Convert newlines to <br> and bold **…**
      return feedback.value
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
        .replace(/\n/g, '<br>')
    })

    // ── Sample words ──────────────────────────────────────────────────
    const sampleWords = async () => {
      const res = await axios.post('/api/sample_words_for_writing', {
        language: practiceLanguage.value,
        primary_language: primaryLanguage.value,
        no_words: noWords.value,
        tags: selectedTags.value,
        tag_filter_mode: tagFilterMode.value,
        tag_match_mode: tagMatchMode.value,
        description: description.value,
        start_date: startDate.value,
        end_date: endDate.value,
      })
      if (res.data.error) throw new Error(res.data.error)
      if (!res.data.words || res.data.words.length === 0) throw new Error('No words returned.')
      return res.data.words
    }

    // ── Session control ───────────────────────────────────────────────
    const startSession = async () => {
      setupError.value = ''
      setupLoading.value = true
      try {
        const words = await sampleWords()
        currentWords.value = words
        round.value = 1
        userText.value = ''
        feedback.value = ''
        sessionStarted.value = true
        await nextTick()
        textareaRef.value?.focus()
      } catch (e) {
        setupError.value = e.message || 'Failed to load words.'
      } finally {
        setupLoading.value = false
      }
    }

    const nextRound = async () => {
      loadingNextWords.value = true
      sessionError.value = ''
      try {
        const words = await sampleWords()
        currentWords.value = words
        round.value++
        userText.value = ''
        feedback.value = ''
        await nextTick()
        textareaRef.value?.focus()
      } catch (e) {
        sessionError.value = e.message || 'Failed to load next words.'
      } finally {
        loadingNextWords.value = false
      }
    }

    const endSession = () => {
      sessionStarted.value = false
      feedback.value = ''
      userText.value = ''
      round.value = 1
    }

    // ── Submit ────────────────────────────────────────────────────────
    const submitText = async () => {
      if (!userText.value.trim() || submitting.value) return
      submitting.value = true
      sessionError.value = ''
      feedback.value = ''
      try {
        const res = await axios.post('/api/evaluate_text', {
          text: userText.value,
          words: currentWords.value,
          language: practiceLanguage.value,
          level: level.value,
        })
        if (res.data.error) throw new Error(res.data.error)
        feedback.value = res.data.feedback || 'No feedback returned.'
      } catch (e) {
        sessionError.value = e.message || 'Evaluation failed. Is the API running?'
      } finally {
        submitting.value = false
      }
    }

    return {
      practiceLanguage, level, noWords, description,
      startDate, endDate,
      tagFilterMode, tagMatchMode, selectedTags, availableTags,
      setupError, setupLoading,
      sessionStarted, round, currentWords,
      userText, textareaRef,
      feedback, feedbackIsClean, formattedFeedback,
      submitting, loadingNextWords, sessionError,
      onLanguageChange, toggleTag,
      startSession, endSession, nextRound, submitText,
    }
  }
}
</script>

<style scoped>
/* ── Layout ──────────────────────────────────────────────────────────── */
.text-eval-tab { max-width: 860px; margin: 0 auto; }

.setup-panel,
.session-panel {
  background: white;
  border-radius: 16px;
  padding: 2.5rem;
  box-shadow: 0 4px 16px rgba(0,0,0,0.09);
}

h2 { margin: 0 0 0.4rem; color: #667eea; font-size: 1.9rem; }
.subtitle { color: #666; margin: 0 0 2rem; font-size: 1rem; line-height: 1.5; }

/* ── Form grid ───────────────────────────────────────────────────────── */
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin-bottom: 1.75rem;
}

.form-group { display: flex; flex-direction: column; gap: 0.4rem; }

.form-group label { font-weight: 600; font-size: 0.9rem; color: #444; }
.optional { font-weight: 400; color: #999; font-size: 0.82rem; }

.language-selector { display: flex; align-items: center; gap: 0.6rem; }
.flag-icon { width: 32px; height: 24px; object-fit: cover; border-radius: 4px; box-shadow: 0 1px 3px rgba(0,0,0,0.15); }

.language-select,
.text-input {
  padding: 0.6rem 0.75rem;
  border: 2px solid #e0e0e0;
  border-radius: 8px;
  font-size: 0.95rem;
  background: white;
  transition: border-color 0.15s;
}
.language-select:focus, .text-input:focus { outline: none; border-color: #667eea; }

.date-input-row { display: flex; align-items: center; gap: 0.4rem; }
.date-input-row .text-input { flex: 1; }
.clear-btn {
  width: 2rem; height: 2rem; padding: 0;
  background: #dc3545; color: white; border: none; border-radius: 50%;
  font-size: 0.8rem; font-weight: 700; cursor: pointer;
  flex-shrink: 0; transition: background 0.15s, transform 0.1s;
}
.clear-btn:hover { background: #b02a37; transform: scale(1.1); }

/* ── Tag filter ──────────────────────────────────────────────────────── */
.tag-filter-group { grid-column: 1 / -1; }

.tag-filter-header { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.75rem; }
.tag-filter-header label { margin-bottom: 0; }

.tag-filter-controls { display: flex; align-items: center; gap: 0.65rem; flex-wrap: wrap; }
.tag-control-pair { display: flex; align-items: center; gap: 0.35rem; }
.tag-control-label { font-size: 0.8rem; font-weight: 600; color: #667eea; }

.tag-mode-buttons { display: flex; border: 2px solid #667eea; border-radius: 6px; overflow: hidden; }
.tag-mode-btn {
  padding: 0.28rem 0.65rem; background: white; color: #667eea;
  border: none; font-size: 0.82rem; font-weight: 600; cursor: pointer;
  transition: background 0.12s, color 0.12s; line-height: 1.4;
}
.tag-mode-btn + .tag-mode-btn { border-left: 2px solid #667eea; }
.tag-mode-btn.active { background: #667eea; color: white; }
.tag-mode-btn:hover:not(.active) { background: #f0f4ff; }

.ignore-tags-btn {
  padding: 0.32rem 0.7rem; background: #6c757d; color: white;
  border: none; border-radius: 6px; font-size: 0.83rem; font-weight: 600;
  cursor: pointer; white-space: nowrap;
}
.ignore-tags-btn:hover { background: #5a6268; }

.test-tag-chips { display: flex; flex-wrap: wrap; gap: 0.45rem; margin-bottom: 0.5rem; }
.test-tag-chip {
  padding: 0.28rem 0.75rem; border: 2px solid #667eea; border-radius: 20px;
  background: white; color: #667eea; font-size: 0.86rem; cursor: pointer;
  transition: background 0.12s, color 0.12s;
}
.test-tag-chip.selected { background: #667eea; color: white; }
.test-tag-chip:hover:not(.selected) { background: #f0f4ff; }

.no-tags-hint { color: #aaa; font-size: 0.86rem; font-style: italic; }

.tag-filter-summary {
  font-size: 0.86rem; color: #555; margin-top: 0.4rem;
  padding: 0.32rem 0.75rem; background: #f0f4ff;
  border-radius: 6px; border-left: 3px solid #667eea;
}

/* ── Buttons ─────────────────────────────────────────────────────────── */
.start-btn {
  width: 100%; padding: 1rem; font-size: 1.1rem; font-weight: 700;
  border: none; border-radius: 10px; cursor: pointer;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white; box-shadow: 0 4px 12px rgba(102,126,234,0.35);
  transition: transform 0.15s, box-shadow 0.15s;
}
.start-btn:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 6px 16px rgba(102,126,234,0.45); }
.start-btn:disabled { opacity: 0.55; cursor: not-allowed; }

/* ── Session header ──────────────────────────────────────────────────── */
.session-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1.75rem; }
.end-btn {
  padding: 0.45rem 1rem; background: #6c757d; color: white;
  border: none; border-radius: 8px; font-size: 0.9rem; font-weight: 600; cursor: pointer;
}
.end-btn:hover { background: #5a6268; }

/* ── Prompt card ─────────────────────────────────────────────────────── */
.prompt-card {
  position: relative;
  background: linear-gradient(135deg, #f5f7fa 0%, #dde3f5 100%);
  border-radius: 14px; padding: 1.5rem 1.75rem; margin-bottom: 1.5rem;
  box-shadow: 0 2px 8px rgba(102,126,234,0.12);
}
.prompt-label { font-size: 0.92rem; color: #555; margin-bottom: 0.85rem; }
.word-chips { display: flex; flex-wrap: wrap; gap: 0.55rem; }
.word-chip {
  padding: 0.45rem 1.1rem; background: white; color: #4a5bbd;
  border: 2px solid #667eea; border-radius: 24px;
  font-size: 1.05rem; font-weight: 700;
  box-shadow: 0 2px 6px rgba(102,126,234,0.15);
}
.round-badge {
  position: absolute; top: 1rem; right: 1.25rem;
  font-size: 0.78rem; font-weight: 600; color: #667eea;
  background: white; border-radius: 12px; padding: 0.2rem 0.65rem;
  box-shadow: 0 1px 4px rgba(0,0,0,0.08);
}

/* ── Writing area ────────────────────────────────────────────────────── */
.write-area { margin-bottom: 0.5rem; }
.writing-textarea {
  width: 100%; padding: 1rem; font-size: 1rem; font-family: inherit;
  border: 2px solid #e0e0e0; border-radius: 10px; resize: vertical;
  transition: border-color 0.15s; box-sizing: border-box; line-height: 1.6;
}
.writing-textarea:focus { outline: none; border-color: #667eea; }
.writing-textarea:disabled { background: #f8f9fa; }
.textarea-hint { font-size: 0.78rem; color: #aaa; text-align: right; margin-top: 0.25rem; }

/* ── Submit row ──────────────────────────────────────────────────────── */
.submit-row { display: flex; gap: 0.75rem; justify-content: flex-end; margin-bottom: 1.5rem; }

.next-btn {
  padding: 0.75rem 1.5rem; font-size: 0.95rem; font-weight: 600;
  border: 2px solid #667eea; background: white; color: #667eea;
  border-radius: 8px; cursor: pointer; transition: background 0.12s, color 0.12s;
}
.next-btn:hover:not(:disabled) { background: #667eea; color: white; }
.next-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.submit-btn {
  padding: 0.75rem 2rem; font-size: 0.95rem; font-weight: 700;
  border: none; border-radius: 8px; cursor: pointer;
  background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
  color: white; box-shadow: 0 3px 10px rgba(40,167,69,0.3);
  transition: transform 0.12s, box-shadow 0.12s;
}
.submit-btn:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 5px 14px rgba(40,167,69,0.4); }
.submit-btn:disabled { opacity: 0.5; cursor: not-allowed; }

/* ── Feedback card ───────────────────────────────────────────────────── */
.feedback-card {
  border-radius: 14px; padding: 1.5rem 1.75rem;
  background: linear-gradient(135deg, #fff8e1 0%, #fff3cd 100%);
  border-left: 5px solid #ffc107;
  box-shadow: 0 2px 10px rgba(255,193,7,0.18);
}
.feedback-card.no-mistakes {
  background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%);
  border-left-color: #28a745;
  box-shadow: 0 2px 10px rgba(40,167,69,0.18);
}

.feedback-header { display: flex; align-items: center; gap: 0.6rem; margin-bottom: 1rem; }
.feedback-icon { font-size: 1.4rem; }
.feedback-title { font-size: 1.1rem; font-weight: 700; color: #333; flex: 1; }
.level-badge {
  padding: 0.2rem 0.65rem; border-radius: 12px; font-size: 0.78rem;
  font-weight: 600; background: rgba(0,0,0,0.07); color: #555;
}
.feedback-body { font-size: 0.97rem; color: #333; line-height: 1.7; }

/* ── Error banner ────────────────────────────────────────────────────── */
.error-banner {
  margin-top: 1rem; padding: 0.85rem 1.25rem;
  background: #f8d7da; color: #721c24; border-radius: 8px;
  font-weight: 500; font-size: 0.93rem;
}

/* ── Transition ──────────────────────────────────────────────────────── */
.fade-slide-enter-active { transition: opacity 0.35s ease, transform 0.35s ease; }
.fade-slide-enter-from { opacity: 0; transform: translateY(12px); }

/* ── Responsive ──────────────────────────────────────────────────────── */
@media (max-width: 640px) {
  .form-grid { grid-template-columns: 1fr; }
  .submit-row { flex-direction: column; }
  .submit-btn, .next-btn { width: 100%; }
}
</style>
