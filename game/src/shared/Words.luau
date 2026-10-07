--!strict
-- Words (D-064, stage 3): the copy rules every toast and results line follows, pure so Lune can
-- read every string. A toast is at most ui.toastMaxWords words (a word has a letter or a digit;
-- an emoji alone is not a word), and no game text uses a wagering word (hard rule 1) or a hurt
-- word (D-058).

local Words = {}

Words.BANNED = {
	-- hard rule 1
	"bet", "bets", "betting", "wager", "wagers", "odds", "stake", "stakes", "payout", "payouts", "house", "bookie", -- policy-ok (the banned list itself)
	-- D-058: no sore, hurt or sick horses
	"hurt", "hurts", "sore", "injury", "injured", "injuries", "limp", "limping", "sick",
}
local BANNED_SET: { [string]: boolean } = {}
for _, w in Words.BANNED do BANNED_SET[w] = true end

-- The words in `text`: runs of non-space characters with a letter or a digit in them.
function Words.list(text: string): { string }
	local out = {}
	for token in string.gmatch(text, "%S+") do
		if string.find(token, "[%a%d]") then table.insert(out, token) end
	end
	return out
end

function Words.count(text: string): number
	return #Words.list(text)
end

-- The first banned word in `text`, or nil.
function Words.banned(text: string): string?
	for word in string.gmatch(string.lower(text), "%a+") do
		if BANNED_SET[word] then return word end
	end
	return nil
end

-- A toast is short and kind: at most `max` words (default 10), no banned word.
function Words.toastOk(text: string, max: number?): (boolean, string?)
	local limit = max or 10
	local n = Words.count(text)
	if n > limit then return false, string.format("%d words (max %d)", n, limit) end
	local bad = Words.banned(text)
	if bad then return false, "uses \"" .. bad .. "\"" end
	return true, nil
end

return Words
