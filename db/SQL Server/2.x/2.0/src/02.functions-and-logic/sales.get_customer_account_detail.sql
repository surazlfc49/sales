IF OBJECT_ID('sales.get_customer_account_detail') IS NOT NULL
DROP FUNCTION sales.get_customer_account_detail;
GO

CREATE FUNCTION sales.get_customer_account_detail
(
    @customer_id			integer,
    @from					date,
    @to						date
)
RETURNS @result TABLE
(
  id						integer IDENTITY, 
  value_date				date, 
  invoice_number			bigint, 
  statement_reference		text, 
  debit						numeric, 
  credit					numeric, 
  balance					numeric
) 
AS
BEGIN
    INSERT INTO @result
	(
		value_date, 
		invoice_number, 
		statement_reference, 
		debit, 
		credit
	)
    SELECT 
		ctv.value_date,
        ctv.invoice_number,
        ctv.statement_reference,
        ctv.debit,
        ctv.credit
    FROM sales.customer_transaction_view ctv
    LEFT JOIN inventory.customers cus
    ON ctv.customer_id = cus.customer_id
    WHERE ctv.customer_id = @customer_id
    AND ctv.value_date BETWEEN @from AND @to;

    UPDATE @result 
    SET balance = c.balance
	FROM @result as result
    INNER JOIN
    (
        SELECT p.id,
            SUM(COALESCE(c.debit, 0) - COALESCE(c.credit, 0)) As balance
        FROM @result p
        LEFT JOIN @result c
        ON c.id <= p.id
        GROUP BY p.id
    ) AS c
    ON result.id = c.id;

    RETURN 
END

GO