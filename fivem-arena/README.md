# bdev_arena — FiveM Arena Script (OOP)

ระบบแข่งขัน 2 ทีม (แดง vs น้ำเงิน) แบบ OOP พร้อมระบบเดิมพันและ Streak System

---

## โครงสร้างไฟล์

```
bdev_arena/
├── fxmanifest.lua
├── shared/
│   ├── config.lua        ← ตั้งค่าทั้งหมดที่นี่
│   └── utils.lua         ← Helper functions
├── server/
│   ├── bank_class.lua    ← จัดการเงินกองกลาง
│   ├── arena_manager.lua ← Logic เกมหลัก (OOP)
│   └── main.lua          ← Event Handlers + Framework init
├── client/
│   ├── arena_class.lua   ← Client state + Zone (OOP)
│   ├── player_class.lua  ← Death detection + Streak (OOP)
│   ├── ui_class.lua      ← NUI Bridge (OOP)
│   └── main.lua          ← Event Handlers + Entry point
└── html/
    ├── index.html
    ├── css/style.css
    └── js/ui.js
```

---

## การติดตั้ง

1. วางโฟลเดอร์ `bdev_arena` ใน `resources/`
2. เพิ่มใน `server.cfg`:
   ```
   ensure bdev_arena
   ```
3. แก้ไข `shared/config.lua` ให้ตรงกับเซิร์ฟเวอร์ของคุณ

---

## Config หลัก (`shared/config.lua`)

| ตัวแปร | ค่า Default | คำอธิบาย |
|---|---|---|
| `Config.MaxPlayersPerTeam` | 5 | ผู้เล่นสูงสุดต่อทีม |
| `Config.TotalRounds` | 3 | จำนวน Round ต่อเกม |
| `Config.RoundDuration` | 300 | วินาทีต่อ Round |
| `Config.BetAmounts` | {10K,25K,50K,100K,250K} | ตัวเลือก Bet |
| `Config.DefaultBet` | 50000 | Bet default |
| `Config.MinBet` | 5000 | ขั้นต่ำ |
| `Config.MaxBet` | 1000000 | สูงสุด |
| `Config.Framework` | 'esx' | 'esx' / 'qbcore' / 'standalone' |
| `Config.ArenaCenter` | vector3(...) | **ต้องแก้** พิกัดกึ่งกลางวง |
| `Config.ArenaRadius` | 30.0 | รัศมีวง (เมตร) |
| `Config.LobbyCenter` | vector3(...) | **ต้องแก้** พิกัดจุด Lobby |
| `Config.SpawnPoints` | {red=..., blue=...} | **ต้องแก้** จุด Spawn แต่ละทีม |

---

## Flow การเล่น

```
1. ผู้เล่นเดินเข้า Lobby Zone → กด [E]
2. คนแรกที่เข้าวงเลือกเป็น Host → เลือกทีม + ตั้งราคาเดิมพัน → Confirm
3. ผู้เล่นอื่นกดเข้าร่วมทีมที่ต้องการ → เงินถูกหักเข้ากองกลางทันที
4. ผู้เล่นครบ 5/5 → Host กดปุ่ม START
5. แข่ง 3 Round — ผู้ชนะอยู่ต่อ ผู้แพ้เด้งออก+รีเซ็ต Streak
6. ผู้แพ้สามารถ Rejoin ใหม่ (หักเงินอีกครั้ง) ก่อน Round ถัดไป
7. จบ 3 Round → ทีมที่ชนะมากกว่าได้รับเงินทั้งหมดจาก Server
8. แสดงผลสรุป → เด้งออกจากเกมอัตโนมัติ
```

---

## Streak System (ไฟ 🔥)

- ชนะติดต่อกัน → Streak +1 แสดงเป็น 🔥🔥🔥 x3
- ตาย / เด้งออก → Streak รีเซ็ตเป็น 0
- Rejoin ใหม่ → Streak เริ่มจาก 0 ใหม่

---

## ACE Permission (Admin)

```
add_ace group.admin arena.admin allow
```

Command admin:
```
/arenarest  ← Reset Arena ทุกสถานะ
```

---

## Architecture (OOP Classes)

### Server
- **`ArenaManager`** — จัดการ State, Round, Score, Spawn, จบเกม
- **`BankClass`** — หักเงิน, กองกลาง, แจกเงินผู้ชนะ, คืนเงิน

### Client
- **`ArenaClass`** — ดู State, Blip, Zone detection, Spawn/Eject
- **`PlayerClass`** — Death detection, Streak counter
- **`UIClass`** — NUI bridge (SendNUIMessage, SetNuiFocus)

---

## Dependencies

- `es_extended` (ESX) **หรือ** `qb-core` (QBCore)  
  ถ้าใช้ `standalone` จะไม่มีการตรวจเงินจริง (ทดสอบเท่านั้น)
