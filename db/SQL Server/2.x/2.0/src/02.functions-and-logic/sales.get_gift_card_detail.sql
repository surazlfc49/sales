IF OBJECT_ID('sales.get_gift_card_detail') IS NOT NULL
DROP FUNCTION sales.get_gift_card_detail;
GO

CREATE FUNCTION sales.get_gift_card_detail
(
    @card_number nvarchar(50),
    @from date,
    @to date
)
RETURNS @result TABLE
(
	id					integer IDENTITY, 
	gift_card_id		integer, 
	transaction_ts		datetime, 
	statement_reference text, 
	debit				numeric, 
	credit				numeric, 
	balance				numeric
)
AS
BEGIN
	INSERT INTO @result
	(
		gift_card_id, 
		transaction_ts, 
		statement_reference, 
		debit,
		credit
	)
	SELECT 
		gift_card_id, 
		transaction_ts, 
		statement_reference, 
		debit, 
		credit
	FROM
	(
		SELECT
			gift_card_transactions.gift_card_id,
			transaction_master.transaction_ts,
			transaction_master.statement_reference,
			CASE WHEN gift_card_transactions.transaction_type = 'Dr' THEN gift_card_transactions.amount END AS debit,
			CASE WHEN gift_card_transactions.transaction_type = 'Cr' THEN gift_card_transactions.amount END AS credit
		FROM sales.gift_card_transactions
		JOIN finance.transaction_master
			ON transaction_master.transaction_master_id = gift_card_transactions.transaction_master_id
		JOIN sales.gift_cards
			ON gift_cards.gift_card_id = gift_card_transactions.gift_card_id
		WHERE 
			gift_cards.gift_card_number = @card_number
		AND 
			transaction_master.transaction_ts BETWEEN @from AND @to
		UNION ALL

		SELECT 
			sales.gift_card_id,
			transaction_master.transaction_ts,
			transaction_master.statement_reference,
			sales.total_amount,
			0
		FROM sales.sales
		LEFT JOIN finance.transaction_master
			ON transaction_master.transaction_master_id = sales.transaction_master_id
		JOIN sales.gift_cards
			ON gift_cards.gift_card_id = sales.gift_card_id
		WHERE sales.gift_card_id IS NOT NULL
		AND gift_cards.gift_card_number = @card_number
		AND transaction_master.transaction_ts BETWEEN @from AND @to
	) t
	ORDER BY t.transaction_ts ASC;

	UPDATE result
	SET balance = c.balance
	FROM @result result
	INNER JOIN	
	(
		SELECT
			p.id, 
			SUM(COALESCE(c.credit, 0) - COALESCE(c.debit, 0)) As balance
		FROM @result p
		LEFT JOIN @result AS c 
			ON (c.transaction_ts <= p.transaction_ts)
		GROUP BY p.id
	) AS c
	ON result.id = c.id;
        
	RETURN
END
GO



