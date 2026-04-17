/* ============================================================
   ARENA UI — JavaScript
   ============================================================ */

'use strict';

// ============================================================
//  STATE
// ============================================================
const State = {
    visible:    false,
    arenaState: 'idle',
    isHost:     false,
    myTeam:     null,
    betAmount:  50000,
    selectedTeam: 'red',
    selectedBet: 50000,
    round:      0,
    totalRounds: 3,
    scores:     { red: 0, blue: 0 },
    streaks:    {},
    teamRed:    [],
    teamBlue:   [],
    hostId:     null,
    pool:       0,
};

// Config bet options (mirror Config.BetAmounts)
const BET_OPTIONS = [10000, 25000, 50000, 100000, 250000];

// ============================================================
//  UI CONTROLLER
// ============================================================
const UI = {
    /* ---------- Visibility ---------- */
    open() {
        document.getElementById('arena-ui').classList.remove('hidden');
        State.visible = true;
    },
    close() {
        document.getElementById('arena-ui').classList.add('hidden');
        State.visible = false;
        fetch('https://bdev_arena/closeUI', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        }).catch(() => {});
    },

    /* ---------- Team Selection ---------- */
    selectTeam(teamId, btn) {
        State.selectedTeam = teamId;
        document.querySelectorAll('.team-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
    },

    /* ---------- Create Lobby ---------- */
    createLobby() {
        const customInput = document.getElementById('bet-custom').value;
        const bet = customInput ? parseInt(customInput, 10) : State.selectedBet;
        if (!bet || bet < 5000) {
            UI.notify('ราคาเดิมพันต้องไม่ต่ำกว่า $5,000', 'error');
            return;
        }
        fetch('https://bdev_arena/createLobby', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ teamId: State.selectedTeam, betAmount: bet }),
        }).catch(() => {});
    },

    /* ---------- Join Team ---------- */
    joinTeam(teamId) {
        fetch('https://bdev_arena/joinTeam', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ teamId }),
        }).catch(() => {});
    },

    /* ---------- Start Game ---------- */
    startGame() {
        fetch('https://bdev_arena/startGame', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        }).catch(() => {});
    },

    /* ---------- Rejoin ---------- */
    rejoin(teamId) {
        fetch('https://bdev_arena/rejoin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ teamId: teamId || State.myTeam || 'red' }),
        }).catch(() => {});
        // ซ่อน rejoin panel
        document.getElementById('rejoin-panel').classList.add('hidden');
    },

    /* ---------- Reset Arena ---------- */
    resetArena() {
        if (!confirm('ยืนยันการยกเลิกเกม?')) return;
        fetch('https://bdev_arena/resetArena', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        }).catch(() => {});
    },

    /* ---------- Notify ---------- */
    notify(msg, type = 'info') {
        const area = document.getElementById('notification-area');
        const div  = document.createElement('div');
        div.className = `notif ${type}`;
        div.textContent = msg;
        area.appendChild(div);
        setTimeout(() => div.remove(), 4000);
    },

    /* ---------- Update full state ---------- */
    updateState(data) {
        if (!data) return;

        State.arenaState = data.state  || 'idle';
        State.isHost     = !!data.isHost;
        State.myTeam     = data.myTeam || null;
        State.betAmount  = data.betAmount || 0;
        State.round      = data.round  || 0;
        State.scores     = data.scores || { red: 0, blue: 0 };
        State.streaks    = data.streaks || {};
        State.teamRed    = data.teamRed  || [];
        State.teamBlue   = data.teamBlue || [];
        State.hostId     = data.host  || null;
        State.pool       = data.pool  || 0;

        UI._renderView();
    },

    /* ---------- Show Rejoin ---------- */
    showRejoin(teamId) {
        document.getElementById('host-panel').classList.add('hidden');
        document.getElementById('join-panel').classList.add('hidden');
        document.getElementById('rejoin-panel').classList.remove('hidden');
    },

    /* ---------- Show/Hide HUD ---------- */
    showHUD(round, total, scores) {
        const hud = document.getElementById('hud-bar');
        hud.classList.remove('hidden');
        hud.style.display = 'flex';
        document.getElementById('hud-round-num').textContent   = round;
        document.getElementById('hud-round-total').textContent = total;
        document.getElementById('hud-red-score').textContent   = scores.red;
        document.getElementById('hud-blue-score').textContent  = scores.blue;
    },

    /* ---------- Countdown ---------- */
    startCountdown(seconds) {
        const el = document.getElementById('hud-countdown');
        el.classList.remove('hidden');
        let remain = seconds;
        const iv = setInterval(() => {
            remain--;
            const m = Math.floor(remain / 60);
            const s = remain % 60;
            el.textContent = `⏱ ${m}:${s.toString().padStart(2,'0')}`;
            if (remain <= 0) {
                clearInterval(iv);
                el.classList.add('hidden');
            }
        }, 1000);
    },

    /* ---------- Streak ---------- */
    updateStreak(streak) {
        State.streaks._self = streak;
        const el = document.getElementById('hud-streak');
        if (streak > 0) {
            el.classList.remove('hidden');
            const flames = '🔥'.repeat(Math.min(streak, 8));
            el.textContent = `${flames} x${streak}`;
        } else {
            el.classList.add('hidden');
        }
    },

    /* ---------- Show Result ---------- */
    showResult(data) {
        const overlay   = document.getElementById('result-overlay');
        const winnerEl  = document.getElementById('result-winner');
        const titleEl   = document.getElementById('result-title');
        const poolEl    = document.getElementById('result-pool');

        document.getElementById('result-red').textContent  = data.scores ? data.scores.red  : 0;
        document.getElementById('result-blue').textContent = data.scores ? data.scores.blue : 0;

        overlay.classList.remove('hidden');

        if (data.winnerTeam === 'red') {
            titleEl.textContent = '🏆 จบเกม!';
            winnerEl.textContent = '🔴 ทีมแดง ชนะ!';
            winnerEl.className = 'result-winner red-win';
        } else if (data.winnerTeam === 'blue') {
            titleEl.textContent = '🏆 จบเกม!';
            winnerEl.textContent = '🔵 ทีมน้ำเงิน ชนะ!';
            winnerEl.className = 'result-winner blue-win';
        } else {
            titleEl.textContent = 'จบเกม!';
            winnerEl.textContent = '🤝 เสมอ!';
            winnerEl.className = 'result-winner draw';
        }

        poolEl.textContent = data.pool > 0 ? `กองกลาง: ${formatMoney(data.pool)}` : '';
    },

    hideResult() {
        document.getElementById('result-overlay').classList.add('hidden');
        document.getElementById('hud-bar').classList.add('hidden');
    },

    /* ============================================================
       INTERNAL RENDER
       ============================================================ */
    _renderView() {
        const s = State.arenaState;

        // Status bar
        const statusMap = {
            idle:    'ไม่มีเกม',
            lobby:   'รอผู้เล่นเข้าร่วม...',
            ready:   'ผู้เล่นครบ! รอ Host กด Start',
            playing: 'กำลังแข่งขัน',
            ended:   'จบเกม',
        };
        document.getElementById('status-label').textContent = statusMap[s] || s;
        document.getElementById('pool-label').textContent =
            State.pool > 0 ? `กองกลาง: ${formatMoney(State.pool)}` : '';

        if (s === 'idle') {
            // แสดง Host Panel
            document.getElementById('host-panel').classList.remove('hidden');
            document.getElementById('join-panel').classList.add('hidden');
            document.getElementById('rejoin-panel').classList.add('hidden');
            UI._buildBetOptions();
        } else if (s === 'lobby' || s === 'ready') {
            // แสดง Join Panel
            document.getElementById('host-panel').classList.add('hidden');
            document.getElementById('join-panel').classList.remove('hidden');
            document.getElementById('rejoin-panel').classList.add('hidden');
            UI._updateJoinPanel();
        } else if (s === 'playing') {
            UI.close();
            UI.showHUD(State.round, State.totalRounds, State.scores);
        } else if (s === 'ended') {
            // handled by showResult event
        }
    },

    _buildBetOptions() {
        const container = document.getElementById('bet-btns');
        container.innerHTML = '';
        BET_OPTIONS.forEach(amount => {
            const btn = document.createElement('button');
            btn.className = 'bet-option' + (amount === State.selectedBet ? ' active' : '');
            btn.textContent = formatMoney(amount);
            btn.onclick = () => {
                State.selectedBet = amount;
                document.getElementById('bet-display').textContent = formatMoney(amount);
                document.getElementById('bet-custom').value = '';
                container.querySelectorAll('.bet-option').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
            };
            container.appendChild(btn);
        });
        document.getElementById('bet-display').textContent = formatMoney(State.selectedBet);

        // custom input listener
        const customInput = document.getElementById('bet-custom');
        customInput.oninput = () => {
            const v = parseInt(customInput.value, 10);
            if (!isNaN(v) && v >= 5000) {
                document.getElementById('bet-display').textContent = formatMoney(v);
                container.querySelectorAll('.bet-option').forEach(b => b.classList.remove('active'));
            }
        };
    },

    _updateJoinPanel() {
        // Bet info
        document.getElementById('join-bet').textContent = formatMoney(State.betAmount);

        // Team counts
        document.getElementById('red-count').textContent  = `${State.teamRed.length}/5`;
        document.getElementById('blue-count').textContent = `${State.teamBlue.length}/5`;

        // Player lists
        UI._renderPlayerList('red-list',  State.teamRed,  State.hostId);
        UI._renderPlayerList('blue-list', State.teamBlue, State.hostId);

        // Host Controls
        const hostControls = document.getElementById('host-controls');
        if (State.isHost) {
            hostControls.classList.remove('hidden');
            const startBtn = document.getElementById('start-btn');
            const ready = State.arenaState === 'ready';
            startBtn.disabled = !ready;
            startBtn.classList.toggle('disabled', !ready);
        } else {
            hostControls.classList.add('hidden');
        }

        // ซ่อน Join buttons ของทีมตัวเอง
        const redJoin  = document.querySelector('.red-join');
        const blueJoin = document.querySelector('.blue-join');
        if (State.myTeam === 'red')  { redJoin.disabled  = true; redJoin.textContent  = '✅ คุณอยู่ทีมนี้'; }
        if (State.myTeam === 'blue') { blueJoin.disabled = true; blueJoin.textContent = '✅ คุณอยู่ทีมนี้'; }
        if (State.teamRed.length  >= 5) { redJoin.disabled  = true; }
        if (State.teamBlue.length >= 5) { blueJoin.disabled = true; }
    },

    _renderPlayerList(containerId, players, hostId) {
        const el = document.getElementById(containerId);
        el.innerHTML = '';
        if (!players || players.length === 0) {
            el.innerHTML = '<span style="color:var(--muted);font-size:0.75rem">ยังไม่มีผู้เล่น</span>';
            return;
        }
        players.forEach(sid => {
            const div = document.createElement('div');
            div.className = 'player-entry' + (sid === hostId ? ' host-tag' : '');
            div.textContent = `ผู้เล่น #${sid}`;
            el.appendChild(div);
        });
    },
};

// ============================================================
//  HELPERS
// ============================================================
function formatMoney(n) {
    return '$' + Math.floor(n).toLocaleString('en-US');
}

// ============================================================
//  NUI MESSAGE HANDLER
// ============================================================
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'setVisible':
            if (data.visible) UI.open();
            else              UI.close();
            break;

        case 'updateState':
            UI.updateState(data.data);
            break;

        case 'notify':
            UI.notify(data.message, data.notifType || 'info');
            break;

        case 'countdown':
            UI.startCountdown(data.seconds);
            break;

        case 'showResult':
            UI.showResult(data.data);
            break;

        case 'hideResult':
            UI.hideResult();
            break;

        case 'updateStreak':
            UI.updateStreak(data.streak);
            break;

        case 'roundInfo':
            UI.showHUD(data.round, data.total, data.scores);
            break;

        case 'showRejoin':
            UI.showRejoin(data.teamId);
            UI.open();
            break;

        default:
            break;
    }
});

// esc to close
window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') UI.close();
});
