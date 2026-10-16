# #4 RFM Customer Segmentation in Pure SQL — starter kit

Tracker row: **#4 RFM Customer Segmentation in Pure SQL** (Order 1, Status: Not started).
Business question: *Who are the champions, the at-risk and the lost customers?*

Ye tere Final-10 ka pehla project hai — aur iska ek direct fayda hai: jaise hi isko
tracker me **Done** mark karega, daily digest ke Data Analyst resumes me ye project
swap ho jayega (rule: Data Analyst → #44 / #4 / #5, sirf Done wale).

## 15-minute quickstart

```bash
cd ~/workspace/goals/final-10-analyst-projects/files/analyst-projects/rfm-starter/
# 1. online_retail_II.xlsx download kar (link neeche), isi folder me rakh
# 2. pip install pandas openpyxl
python bootstrap.py          # xlsx -> retail.db (sirf plumbing, 1 command)
sqlite3 retail.db < rfm_segmentation.sql   # poora analysis, pure SQL
```

Dataset: https://archive.ics.uci.edu/dataset/502/online+retail+ii
(UCI Online Retail II — UK-based online retail, Dec 2009 – Dec 2011, ~1M rows.)

## Tracker ke 4 steps → SQL me kahan hain

| Tracker step | SQL me |
|---|---|
| 1. Clean cancellations & negative quantities | `rfm_clean` view — cancels (`C*` invoices), returns, zero-price, guest checkouts sab bahar |
| 2. R/F/M per customer with CTEs | `rfm_base` view — snapshot date = max invoice date; recency in days, frequency = distinct invoices, monetary = sum(line total) |
| 3. Score 1–5 with NTILE, RFM code | `rfm_scored` view — teeno axes pe higher = better; code = `r||f||m` (e.g. `555`) |
| 4. 125 codes → 8 segments with CASE WHEN | `rfm_segments` view — har (r,f) combo exactly ek segment me |

## 8 segments (ye table README me yaad rakh — interview me kaam ayega)

| Segment | Matlab | Typical action |
|---|---|---|
| Champions | Recent + frequent + high spend | Reward, early access — ye brand ambassadors hain |
| Loyal Customers | Frequent, thoda less recent | Upsell / cross-sell |
| Potential Loyalists | Recent, medium frequency | Nurture — ye agle Champions hain |
| New Customers | Abhi aaye, ek hi purchase | Onboarding offers, second purchase push |
| Promising | Recent lekin sirf ek purchase | Follow-up, reviews mango |
| Need Attention | Beech me atke hue | Limited-time offers |
| At Risk | Pehle frequent the, ab gayab | Win-back campaign — jaldi karo |
| Hibernating | Kabhi-kabhi aate the, ab so rahe | Saste win-back ya chhod do |

## Done checklist (tracker me Done mark karne se pehle)

- [ ] `rfm_segmentation.sql` bina error chala, teeno views bane
- [ ] Segment summary me 8 segments dikhe + revenue share nikla
- [ ] Sanity check: `COUNT(DISTINCT rfm_code) <= 125`
- [ ] Repo me push (naya repo `rfm-customer-segmentation` ya existing me folder)
- [ ] `Final-10-Analyst-Projects.xlsx` me #4 → Done
- [ ] Done hote hi digest ke Data Analyst resumes me ye project aane lagega

## Interview me bolne layak 3 lines

1. "Maine RFM pure SQL me kiya — no Python. Cleaning se lekar NTILE scoring aur segment mapping tak sab views me hai, to segmentation reusable hai."
2. "Recency ko snapshot date se measure kiya, aur NTILE ke tie-handling ka dhyan rakha — same frequency wale customers arbitrary buckets me bat sakte hain, isliye production me distribution-based cutoffs better honge."
3. "Segment sirf R/F pe banaye, M ko revenue-share ke liye rakha — kyunki 'At Risk' high-spender aur 'At Risk' low-spender ke liye action alag hota hai."

## Ek caveat (pehle se pata ho to achha)

`NTILE(5)` rows ko barabar baant ta hai — ties (jaise hazaaron customers with frequency = 1)
arbitrary buckets me kat jate hain. Is dataset pe result sahi aata hai, lekin interview me
ye point khud bol dena — yehi cheez tujhe "SQL chalana aata hai" se "SQL samajhta hai" pe le jati hai.
