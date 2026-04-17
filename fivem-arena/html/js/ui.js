/* ============================================================
   ARENA HUD + RESULT — JavaScript
   (Lobby ทั้งหมดใช้ ox_lib context menu ฝั่ง Lua แล้ว)
   ============================================================ */

'use strict';

// ============================================================
//  HUD CONTROLLER
// ============================================================
const HUD = {
    el:           document.getElementById('hud-bar'),
    roundNum:     document.getElementById('hud-round-num'),
    roundTotal:   document.getElementById('hud-round-total'),
    redScore:     document.getElementById('hud-red-score'),
    blueScore:    document.getElementById('hud-blue-score'),
    streakEl:     document.getElementById('hud-streak'),
    countdownEl:  document.getElementById('hud-countdown'),

    _countdownIv: null,

    show(round, total, scores) {
        this.roundNum.textContent   = round;
        this.roundTotal.textContent = total;
        this.redScore.textContent   = scores?.red  ?? 0;
        this.blueScore.textContent  = scores?.blue ?? 0;
        this.el.classList.remove('hidden');
    },

    hide() {
        this.el.classList.add('hidden');
        this.hideStreak();
        this.stopCountdown();
    },

    updateScores(scores) {
        this.redScore.textContent  = scores?.red  ?? 0;
        this.blueScore.textContent = scores?.blue ?? 0;
    },

    showStreak(streak) {
        if (streak <= 0) { this.hideStreak(); return; }
        const flames = '🔥'.repeat(Math.min(streak, 8));
        this.streakEl.textContent = `${flames} ×${streak}`;
        this.streakEl.classList.remove('hidden');
    },

    hideStreak() {
        this.streakEl.classList.add('hidden');
    },

    startCountdown(seconds) {
        this.stopCountdown();
        let remain = seconds;
        const update = () => {
            const m = Math.floor(remain / 60);
            const s = remain % 60;
            this.countdownEl.textContent = `⏱ ${m}:${String(s).padStart(2, '0')}`;
            this.countdownEl.classList.remove('hidden');
            this.countdownEl.classList.toggle('urgent', remain <= 30);
        };
        update();
        this._countdownIv = setInterval(() => {
            remain--;
            if (remain < 0) { this.stopCountdown(); return; }
            update();
        }, 1000);
    },

    stopCountdown() {
        if (this._countdownIv) { clearInterval(this._countdownIv); this._countdownIv = null; }
        this.countdownEl.classList.add('hidden');
        this.countdownEl.classList.remove('urgent');
    },
};

// ============================================================
//  RESULT CONTROLLER
// ============================================================
const Result = {
    overlay:    document.getElementById('result-overlay'),
    titleEl:    document.getElementById('result-title'),
    winnerEl:   document.getElementById('result-winner'),
    redEl:      document.getElementById('result-red'),
    blueEl:     document.getElementById('result-blue'),
    poolEl:     document.getElementById('result-pool'),
    timerEl:    document.getElementById('result-timer'),

    _dismissIv: null,

    show(data) {
        this.redEl.textContent  = data.scores?.red  ?? 0;
        this.blueEl.textContent = data.scores?.blue ?? 0;
        this.poolEl.textContent = data.pool > 0 ? `กองกลาง: ${fmtMoney(data.pool)}` : '';

        if (data.winnerTeam === 'red') {
            this.titleEl.textContent  = '🏆 จบเกม!';
            this.winnerEl.textContent = '🔴 ทีมแดง ชนะ!';
            this.winnerEl.className   = 'result-winner red-win';
        } else if (data.winnerTeam === 'blue') {
            this.titleEl.textContent  = '🏆 จบเกม!';
            this.winnerEl.textContent = '🔵 ทีมน้ำเงิน ชนะ!';
            this.winnerEl.className   = 'result-winner blue-win';
        } else {
            this.titleEl.textContent  = 'จบเกม!';
            this.winnerEl.textContent = '🤝 เสมอ!';
            this.winnerEl.className   = 'result-winner draw';
        }

        this.overlay.classList.remove('hidden');

        // Countdown dismiss
        let secs = 8;
        this.timerEl.textContent = secs;
        this._dismissIv = setInterval(() => {
            secs--;
            this.timerEl.textContent = secs;
            if (secs <= 0) this.hide();
        }, 1000);
    },

    hide() {
        if (this._dismissIv) { clearInterval(this._dismissIv); this._dismissIv = null; }
        this.overlay.classList.add('hidden');
        HUD.hide();
    },
};

// ============================================================
//  HELPERS
// ============================================================
function fmtMoney(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
}

// ============================================================
//  NUI MESSAGE HANDLER
// ============================================================
window.addEventListener('message', ({ data }) => {
    if (!data?.action) return;

    switch (data.action) {

        case 'roundInfo':
            HUD.show(data.round, data.total, data.scores);
            break;

        case 'countdown':
            HUD.startCountdown(data.seconds);
            break;

        case 'updateStreak':
            HUD.showStreak(data.streak);
            break;

        case 'hideHUD':
            HUD.hide();
            break;

        case 'showResult':
            Result.show(data.data);
            break;

        case 'hideResult':
            Result.hide();
            break;

        default:
            break;
    }
});
