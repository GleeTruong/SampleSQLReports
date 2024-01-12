/*
Invoice Report that shows the status of the invoice and keeping track of payment information.
Set up meant to run in Excel due to software limitation and security.
*/

Select 
BID.Batch_ID,
Case 
	when CI.SiteID = 20 then 'Socal'
	when CI.SiteID = 25 then 'Nocal'
	else 'Unknown'
End as SiteDesc,
CI.CustomerType,
CI.CustomerID,	   
Case
	when CI.CustomerType = 'CH' then CH.CH_NM
	when CI.CustomerType = 'CU' then CU.Name
	when CI.CustomerType = 'CC' then CC.CCName
	else ''
End as CustomerName,
CI.SupplierID,
Case
	when CI.SupplierID = '10100479'
		then 'PATRON SPIRITS COMPANY VIRTUAL'
	when CI.SupplierID = '10100464'
		then 'MOET HENNESSY USA VIRTUAL'
	when CI.SupplierID = '10100476'
		then 'MAST JAGERMEISTER US VIRTUAL'
	when CI.SupplierID='10100534'
		then 'DIAGEO NOLET VIRTUAL'
	Else SU.Suname
End as SupplierName,
CI.InvoiceNumber,
CI.InvoiceSuffix,	   
Case
	when CI.InvoiceStatusCode = 'P' then 'Paid'
	when CI.InvoiceStatusCode = 'O' then 'Open'
	when CI.InvoiceStatusCode = 'F' then 'Finalized'
	else 'Undefined'
End as InvoiceStatusCode,
CI.InvoiceDate,
CI.InvoiceDueDate,
CI.PayoutCustomerID,
PC.Name as PayoutCustomerName,
CI.InvoiceBudgetMonth,
PR.ScanContractID,
PR.ProgramDescription,
PR.StartDatePeriod,
PR.EndDatePeriod,
PR.ControlNumber,
PR.ControlSequenceNumber,
PO.ItemID,
IM.Brand_Name as Brand,
IM.Descriptn as ItemDesc,
IM.PROD_CAT as IType,
IM.Size,
IM.Bttls_PCAS as BCP,
PO.TotalUnits,
PO.PayRate,
PO.AdminCharge,
PO.TotalPayOut,
Case
	when PO.PayoutStatus = 'P' then 'Paid'
	when PO.PayoutStatus = 'O' then 'Open'
	when PO.PayoutStatus = 'F' then 'Finalized'
	else 'Undefined'
End as PayoutStatus,
AL.CheckDate,
AL.CheckNumber,
AL.CheckAmount,
AL.CheckClearingFlag

From Scan.dbo.SCANCustomerInvoice as CI
Join Scan.dbo.ScanPayOutDetail as PO on CI.ScanCustomerInvoiceID = PO.ScanCustomerInvoiceID
Left Join Scan.dbo.ScanAccountLedger as AL on PO.ScanAccountLedgerID = AL.ScanAccountLedgerID
Join Scan.dbo.ScanProgram as PR	on PO.ScanProgramID = PR.ScanProgramID
Left Join Core_ETP.dbo.CHNMSTFTP as CH on CI.CustomerType = 'CH' and CI.CustomerID = CH.CH_NR and CI.SiteID = CH.Site
Left Join Core_ETP.dbo.OE010PFTP as CU on CI.CustomerType = 'CU' and CI.SiteID = CU.Site
Left Join Core_ETP.dbo.CC080PFTP as CC on CI.CustomerType = 'CC' and CI.CustomerID = CC.CCCHNO and CI.SiteID = CC.CCSite
Left Join Core_ETP.dbo.OE060PFTP as SU on CI.SupplierID = SU.Suno and CI.SiteID = SU.Site
Left Join Core_ETP.dbo.OE010PFTP as PC on CI.PayoutCustomerID = PC.Customer and CI.SiteID = PC.Site
Left Join Core_ETP.dbo.ItemFtp as IM on PO.ItemID = IM.Item and CI.SiteID = IM.Site
Left Join
  (
	Select max(a.Batch_ID) as Batch_ID, 
		a.Contract_ID, 
		a.Invoice_Number  
	from [Scan].[dbo].[ScanUploadStagingFile] as a
	Join Scan.dbo.ScanUploadBatchFile as b
		on a.Batch_ID = b.Batch_ID
	where b.Status = 'PC'
	Group by a.Contract_ID, a.Invoice_Number
  ) as BID
    on PR.ScanContractID = BID.Contract_ID and CI.InvoiceNumber = BID.Invoice_Number
 

where CI.Siteid in (20,25) and 
CI.InvoiceBudgetMonth >= ? and
CI.InvoiceBudgetMonth <= ?

----------------------------------------------------------------------------------------------------------------------------------------
/*
Simple CTE allowing users to check for duplicates and see what dates there are double inputs
*/

WITH CTE as
(Select *,
	row_number() over(partition by SuppFundDesc order by Createddate Desc) as RN
FROM Scan.dbo.SAPImportFundBalHistory SAPImportFundBalHistory)

Select CTE.SAPImportFundBalID, CTE.Companycode, CTE.SupplierId, CTE.SupplierName, CTE.SuppFundDesc, CTE.CustFundNo, CTE.FundApplication, CTE.Fundamount, CTE.Classification, CTE.FundType, CTE.FundingSource, CTE.Category, CTE.Createddate
From CTE
Where RN =1

----------------------------------------------------------------------------------------------------------------------------------------
/*
Formating dates in Business Objects as a varible to compare to FY data and help generate monthly reports to be automated.
*/

=If[Scan Invoice Budget Month]<=ToNumber(FormatDate([Static Supplier Fiscal Period To];"yyyyMM")) And  [Scan Invoice Budget Month] >= ToNumber(FormatDate([Static Supplier Fiscal Period From];"yyyyMM")) Then FormatDate([Static Supplier Fiscal Period To];"yyyy")
Else If [Scan Invoice Budget Month] <= ToNumber(FormatDate([Static Supplier Fiscal Period To];"yyyyMM"))-100 And [Scan Invoice Budget Month] >= ToNumber(FormatDate([Static Supplier Fiscal Period From];"yyyyMM")) -100 Then FormatDate(ToDate([Scan Invoice Budget Month]+ "01";"yyyyMMdd");"yyyy")
Else If [Scan Invoice Budget Month] <= ToNumber(FormatDate([Static Supplier Fiscal Period To];"yyyyMM"))-200 And [Scan Invoice Budget Month] >= ToNumber(FormatDate([Static Supplier Fiscal Period From];"yyyyMM")) -200 Then FormatDate(ToDate([Scan Invoice Budget Month]+ "01";"yyyyMMdd");"yyyy")
Else If [Scan Invoice Budget Month] <= ToNumber(FormatDate([Static Supplier Fiscal Period To];"yyyyMM"))-300 And [Scan Invoice Budget Month] >= ToNumber(FormatDate([Static Supplier Fiscal Period From];"yyyyMM")) -300 Then FormatDate(ToDate([Scan Invoice Budget Month]+ "01";"yyyyMMdd");"yyyy")
Else ""

--Note: FY from main data source are always the current one so manipulation is needed

SELECT
  scan_program.scan_contract_info,
  site.site,
  scan_program.program_description,
  supplier.suppl_no,
  supplier.suppl_name,
  item_current.item_no,
  item_current.item_desc,
  item_current.item_size,
  item_current.brand_name,
  sum(customer_invoice.total_units_qty),
  sum(scan_program.pay_rate),
  customer_invoice.total_units_qty * customer_invoice.admin_charge_amt ,
  sum(customer_invoice.total_payout),
  customer_current.customer_name,
  scan_program.account_type_cd,
  customer_invoice.invoice_budget_month,
  scan_program.program_start_period_dt,
  scan_program.program_end_period_dt,
  supplier.scan_fiscal_month,
  supplier.scan_fiscal_peroid_from,
  supplier.scan_fiscal_peroid_to
FROM
  scan.v_d_site  site JOIN scan.v_f_customer_invoice  customer_invoice ON (site.site=customer_invoice.site_id)
   LEFT OUTER JOIN scan.v_d_scan_program  scan_program ON (customer_invoice.scan_program_id = scan_program.scan_program_id  AND  customer_invoice.scan_program_sk = scan_program.scan_program_sk)
   JOIN onesource_datamart.v_d_customer  customer_current ON (customer_invoice.site_id = customer_current.site  AND  customer_invoice.alternative_payout_customer_no = customer_current.customer_no)
   JOIN onesource_datamart.v_d_curr_item  item_current ON (customer_invoice.site_id =item_current.site    AND  customer_invoice.item_id =  item_current.item_no)
   LEFT OUTER JOIN scan.v_d_supplier  supplier ON (customer_invoice.site_id = supplier.site  AND  customer_invoice.supplier_no = supplier.suppl_no)
  
WHERE
  ( site.site in (20,25) )  AND  
  (
   customer_invoice.invoice_budget_month  >=  202201
   AND
   site.site  IN  ( 20,25  )
  )
GROUP BY
  scan_program.scan_contract_info, 
  site.site, 
  scan_program.program_description, 
  supplier.suppl_no, 
  supplier.suppl_name, 
  item_current.item_no, 
  item_current.item_desc, 
  item_current.item_size, 
  item_current.brand_name, 
  customer_invoice.total_units_qty * customer_invoice.admin_charge_amt , 
  customer_current.customer_name, 
  scan_program.account_type_cd, 
  customer_invoice.invoice_budget_month, 
  scan_program.program_start_period_dt, 
  scan_program.program_end_period_dt, 
  supplier.scan_fiscal_month, 
  supplier.scan_fiscal_peroid_from, 
  supplier.scan_fiscal_peroid_to
  
-------------------------------------------------------------------------------------------------------------------------------
/*
Subquery duplicate checker since Excel doesn't like CTE much.
*/  
  
Select *
From SAPImportPayRefHistory
Where SCANRefInvoice in (
	select ScanRefInvoice
	from SAPImportPayRefHistory
	Group By SCANRefInvoice
	having count(ScanRefInvoice) > 1)
Order By SCANRefInvoice,Createddate

-------------------------------------------------------------------------------------------------------------------------------

/*
Case quantity exposure report
*/

Select * from
(select  Case 
              when p.SiteId = 0 then 'Statewide' 
              when p.SiteId = 25 then 'N-Cal' 
              when p.SiteId = 20 then 'S-Cal' 
              else 'Unknown' 
              End as Location, 
              p.SupplierId, 
              Case when p.SupplierId = 100033 and chris4.prod_cat = 'W' then 'Pernod Ricard USA (Wines)'
                       when p.SupplierId = 100033 and chris4.prod_cat != 'W' then 'Pernod Ricard USA (Spirits)'
                       else s.SupplierName
                       end as 'Supplier',
          Case 
              when p.CompanyId = 1 then 'SWS' 
              when p.CompanyId = 2 then 'PWS' 
              when p.CompanyId = 3 then 'AWS' 
              when p.CompanyId = 4 then 'RWS' 
              when p.CompanyId = 5 then 'TAS' 
              else 'Unknown' 
              End as Company, 
          p.ProgramDescription as 'Program_Description', 
          Case 
              when p.ProgramTypeCode = 'CH' then 'Chains' 
              when p.ProgramTypeCode = 'BM' then 'GM' 
              when p.ProgramTypeCode = 'SS' then 'Chains' 
              else 'Unknown' 
              End as ProgramType, 
          p.StartDatePeriod as ProgramStartDatePeriod, 
          Substring(Cast(p.StartDatePeriod as char(8)),1,6) as 'StartPeriod', 
          p.EndDatePeriod as ProgramEndDatePeriod, 
          Substring(Cast(p.EndDatePeriod as char(8)),1,6) as 'EndPeriod', 
          p.ControlNumber, 
          p.ControlSequenceNumber, 
          case 
                  when a.FinancialCreditCustomerSiteId = 20 then 'S-Cal'
                  else 'N-Cal'
                  end as FinancialCreditCustomerSite,
          a.FinancialCreditCustomerId, 
          c.Name as FinancialCreditCustomerName, 
          a.PaymentReferenceNumber, 
          a.FinancialCreditMemoNumber, 
          a.CreditMemoDate, 
          a.SapphireCQDProgramNumber, 
          Case 
              when a.BillingStatusCode = 'O' then 'Open' 
              when a.BillingStatusCode = 'P' then 'Paid' 
              when a.BillingStatusCode = 'I' then 'In-Process' 
              else 'Unknown' 
              End as BillingStatus, 
          Case 
              when ca7.ApproveDecline = 'D' then 'Declined by FA' 
              when ca6.ApproveDecline = 'D' then 'Declined by SU' 
              when ca5.ApproveDecline = 'D' then 'Declined by CE' 
              when ca4.ApproveDecline = 'D' then 'Declined by AE' 
              when ca3.ApproveDecline = 'D' then 'Declined by EX' 
              when ca2.ApproveDecline = 'D' then 'Declined by DM' 
              when ca1.ApproveDecline = 'D' then 'Declined by SR' 
              when ca1.ApproveDecline = 'P' then 'Pending REP/AE Approval' 
              when ca2.ApproveDecline = 'P' then 'Pending DM Approval' 
              when ca3.ApproveDecline = 'P' then 'Pending EX/CE Approval' 
              when ca4.ApproveDecline = 'P' then 'Pending REP/AE Approval' 
              when ca5.ApproveDecline = 'P' then 'Pending EX/CE Approval' 
              when ca6.ApproveDecline = 'P' then 'Pending Supplier Approval' 
              when ca7.ApproveDecline = 'P' then 'Pending Final Approval' 
              when ca7.ApproveDecline = 'A' then 'Approved' 
              else 'Unknown' 
              End as ApproveDeclineStatus, 
          a.InvoiceGroupNumber as OnInvoice, 
          Case 
                     when p.CompanyID = 1 then t1.TeamNumber 
                     when p.CompanyID = 2 then t2.TeamNumber 
                     when p.CompanyID = 3 then t3.TeamNumber 
                     when p.CompanyID = 4 then t4.TeamNumber 
                     when p.CompanyID = 5 then t5.TeamNumber 
                     else t1.TeamNumber 
           End as TeamNumber, 
          Case 
                     when p.CompanyID = 1 then t1.TeamName 
                     when p.CompanyID = 2 then t2.TeamName 
                     when p.CompanyID = 3 then t3.TeamName 
                     when p.CompanyID = 4 then t4.TeamName 
                     when p.CompanyID = 5 then t5.TeamName 
                     else t1.TeamName 
           End as TeamName, 
          Case 
                     when p.CompanyID = 1 then a.SWSRepID 
                     when p.CompanyID = 2 then a.PWSRepID 
                     when p.CompanyID = 3 then a.AWSRepID 
                     when p.CompanyID = 4 then a.RWSRepID 
                     when p.CompanyID = 5 then a.TASRepID 
                     else a.SWSRepID 
           End as RepNumber, 
       Case 
                     when p.CompanyID = 1 then t1.SalesRepName 
                     when p.CompanyID = 2 then t2.SalesRepName 
                     when p.CompanyID = 3 then t3.SalesRepName 
                     when p.CompanyID = 4 then t4.SalesRepName 
                     when p.CompanyID = 5 then t5.SalesRepName 
                     else t1.SalesRepName 
           End as RepName, 
          d.ItemId, 
          i.Descriptn as 'Item_Description', 
          i.Size, 
          i.BPC, 
          i.Brand as 'Brandid', 
          i.Brand_Name as 'Brand', 
          d.TotalUnits as Cases, 
          d.PayRate, 
          d.TotalAllowance as 'Payout', 
          d.CompanyAmount, 
          d.SupplierAmount, 
          d.BankAmount, 
          a.CreatedDate, 
          ca1.ApproveDeclineDate as SRApproveDeclineDate, 
          ca2.ApproveDeclineDate as DMApproveDeclineDate, 
          ca3.ApproveDeclineDate as EXApproveDeclineDate, 
          ca4.ApproveDeclineDate as AEApproveDeclineDate, 
          ca5.ApproveDeclineDate as CEApproveDeclineDate, 
          ca6.ApproveDeclineDate as SUApproveDeclineDate, 
          ca7.ApproveDeclineDate as FAApproveDeclineDate, 
          chris2.UserName as 'CQD Modified By', 
          Case 
                     when a.CreatedBy = 1 then 'system' 
                     else chris3.UserName 
           End as 'CQD Created By'
  from CQD_SS.dbo.CQDProgram as p 
  Join CQD_SS.dbo.CQDAllowance as a on p.CQDProgramId = a.CQDProgramId 
  Join CQD_SS.dbo.CQDAllowanceDetail as d on a.CQDAllowanceId = d.CQDAllowanceId 
  Left Join 
              ( 
              Select SupplierNumber as SupplierId, max(SupplierName) as SupplierName 
                 from CQD_SS.dbo.v_Supplier  Group by SupplierNumber 
              ) as s 
    on p.SupplierId = s.SupplierId 
  Left Join CQD_SS.dbo.v_CustomerMaster as c on a.FinancialCreditCustomerSiteId = c.Site and a.FinancialCreditCustomerId = c.Customer 
  Left Join CQD_SS.dbo.v_ItemMaster as i on a.FinancialCreditCustomerSiteId = i.Site and 
          d.ItemId = i.Item 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t1 
    on a.FinancialCreditCustomerSiteID = t1.SiteId and 
          a.SWSRepID = t1.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t2 
    on a.FinancialCreditCustomerSiteID = t2.SiteId and 
          a.PWSRepID = t2.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t3 
    on a.FinancialCreditCustomerSiteID = t3.SiteId and 
          a.AWSRepID = t3.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t4 
    on a.FinancialCreditCustomerSiteID = t4.SiteId and 
          a.RWSRepID = t4.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t5 
    on a.FinancialCreditCustomerSiteID = t5.SiteId and 
          a.TASRepID = t5.SalesRepNumber 
  Left Join CQD_SS.dbo.CQDApproval as ca1 
    on a.CQDAllowanceId = ca1.CQDAllowanceiD and 
          ca1.ApproveDeclineByType = 'SR' 
  Left Join CQD_SS.dbo.CQDApproval as ca2 
    on a.CQDAllowanceId = ca2.CQDAllowanceiD and 
          ca2.ApproveDeclineByType = 'DM' 
  Left Join CQD_SS.dbo.CQDApproval as ca3 
    on a.CQDAllowanceId = ca3.CQDAllowanceiD and 
          ca3.ApproveDeclineByType = 'EX' 
  Left Join CQD_SS.dbo.CQDApproval as ca4 
    on a.CQDAllowanceId = ca4.CQDAllowanceiD and 
          ca4.ApproveDeclineByType = 'AE' 
  Left Join CQD_SS.dbo.CQDApproval as ca5 
    on a.CQDAllowanceId = ca5.CQDAllowanceiD and 
          ca5.ApproveDeclineByType = 'CE' 
  Left Join CQD_SS.dbo.CQDApproval as ca6 
    on a.CQDAllowanceId = ca6.CQDAllowanceiD and 
          ca6.ApproveDeclineByType = 'SU' 
  Left Join CQD_SS.dbo.CQDApproval as ca7 
    on a.CQDAllowanceId = ca7.CQDAllowanceiD and 
          ca7.ApproveDeclineByType = 'FA' 
  Left Join CQD.dbo.v_Users as chris2 
	on chris2.UserID = a.ModifiedBy 
  Left Join CQD.dbo.v_Users as chris3 
	on chris3.UserID = a.CreatedBy
  Left Join (Select item,MAX(prod_cat) as prod_cat from [CORE_ETP].[dbo].[ITEMFTP] group by item) as chris4
	on d.itemid = chris4.item 
 where p.ProgramStatusCode in ('F', 'I', 'P', 'R', 'X') 
   and p.StateID = 5) as data
where ApproveDeclineStatus like '%pending%'



UNION ALL


Select 
MAX(Location),	
MAX(SupplierId),
MAX(Supplier),	
MAX(Company),	
MAX(Program_Description),	
ProgramType,	
MAX(ProgramStartDatePeriod),	
StartPeriod,
MAX(ProgramEndDatePeriod),	
MAX(EndPeriod),	
MAX(ControlNumber),	
MAX(ControlSequenceNumber),
FinancialCreditCustomerSite,	
MAX(FinancialCreditCustomerId),	
MAX(FinancialCreditCustomerName),	
MAX(PaymentReferenceNumber),	
MAX(FinancialCreditMemoNumber),	
MAX(CreditMemoDate),	
MAX(SapphireCQDProgramNumber),	
MAX(BillingStatus),
MAX(ApproveDeclineStatus),	
MAX(OnInvoice),	
MAX(TeamNumber),	
MAX(TeamName),	
MAX(RepNumber),	
MAX(RepName),	
MAX(ItemId),	
MAX(Item_Description),	
MAX(Size),	
MAX(BPC),
MAX(Brandid),
MAX(Brand),	
MAX(Cases),	
MAX(PayRate),	
MAX(Payout),	
MAX(CompanyAmount),	
MAX(SupplierAmount),	
MAX(BankAmount),	
MAX(CreatedDate),
MAX(SRApproveDeclineDate),
MAX(DMApproveDeclineDate),	
MAX(EXApproveDeclineDate),	
MAX(AEApproveDeclineDate),	
MAX(CEApproveDeclineDate),	
MAX(SUApproveDeclineDate),	
MAX(FAApproveDeclineDate),
MAX('CQD Modified By'),
MAX('CQD Created By')

From
(select  
	'fill' as Location,  
	100033 as SupplierId, 
    'Pernod Ricard USA (Spirits)' as Supplier, 
    'fill' as Company, 
    'fill' as Program_Description, 
          Case 
              when p.ProgramTypeCode = 'CH' then 'Chains' 
              when p.ProgramTypeCode = 'BM' then 'GM' 
              when p.ProgramTypeCode = 'SS' then 'GM' 
              else 'Unknown' 
              End as ProgramType, 
          0 as ProgramStartDatePeriod, 
          Substring(Cast(p.StartDatePeriod as char(8)),1,6) as 'StartPeriod', 
          0 as ProgramEndDatePeriod, 
          0 as 'EndPeriod', 
          0 as 'ControlNumber', 
          0 as 'ControlSequenceNumber', 
          case 
                  when a.FinancialCreditCustomerSiteId = 20 then 'S-Cal'
                  else 'N-Cal'
                  end as FinancialCreditCustomerSite,
          0 as 'FinancialCreditCustomerId', 
          'fill' as 'FinancialCreditCustomerName', 
          0 as 'PaymentReferenceNumber', 
          0 as 'FinancialCreditMemoNumber', 
          0 as 'CreditMemoDate', 
          0 as 'SapphireCQDProgramNumber', 
          'fill' as 'BillingStatus', 
          'Pending DM Approval' as 'ApproveDeclineStatus', 
          0 as 'OnInvoice', 
          0 as 'TeamNumber', 
          'fill' as 'TeamName', 
          0 as 'RepNumber', 
         'fill' as 'RepName', 
          0 as 'ItemId', 
          'fill' as 'Item_Description', 
          'fill' as 'Size', 
          0 as 'BPC', 
          0 as 'Brandid', 
          'fill' as 'Brand', 
          0 as 'Cases', 
          0 as 'PayRate', 
          0 as 'Payout', 
          0 as 'CompanyAmount', 
          0 as 'SupplierAmount', 
          0 as 'BankAmount', 
          0 as 'CreatedDate', 
          0 as SRApproveDeclineDate, 
          0 as DMApproveDeclineDate, 
          0 as EXApproveDeclineDate, 
          0 as AEApproveDeclineDate, 
          0 as CEApproveDeclineDate, 
          0 as SUApproveDeclineDate, 
          0 as FAApproveDeclineDate, 
          'fill' as 'CQD Modified By', 
          'fill' as 'CQD Created By'
  from CQD_SS.dbo.CQDProgram as p 
  Join CQD_SS.dbo.CQDAllowance as a 
    on p.CQDProgramId = a.CQDProgramId 
  Join CQD_SS.dbo.CQDAllowanceDetail as d 
    on a.CQDAllowanceId = d.CQDAllowanceId 
  Left Join 
              ( 
              Select SupplierNumber as SupplierId, max(SupplierName) as SupplierName 
                 from CQD_SS.dbo.v_Supplier  Group by SupplierNumber 
              ) as s 
    on p.SupplierId = s.SupplierId 
  Left Join CQD_SS.dbo.v_CustomerMaster as c 
    on a.FinancialCreditCustomerSiteId = c.Site and 
          a.FinancialCreditCustomerId = c.Customer 
  Left Join CQD_SS.dbo.v_ItemMaster as i 
    on a.FinancialCreditCustomerSiteId = i.Site and 
          d.ItemId = i.Item 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t1 
    on a.FinancialCreditCustomerSiteID = t1.SiteId and 
          a.SWSRepID = t1.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t2 
    on a.FinancialCreditCustomerSiteID = t2.SiteId and 
          a.PWSRepID = t2.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t3 
    on a.FinancialCreditCustomerSiteID = t3.SiteId and 
          a.AWSRepID = t3.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t4 
    on a.FinancialCreditCustomerSiteID = t4.SiteId and 
          a.RWSRepID = t4.SalesRepNumber 
  Left Join (Select distinct SiteID, SalesRepNumber, SalesRepName, TeamNumber, TeamName from CQD_SS.dbo.v_DMofSalesRep) as t5 
    on a.FinancialCreditCustomerSiteID = t5.SiteId and 
          a.TASRepID = t5.SalesRepNumber 
  Left Join CQD_SS.dbo.CQDApproval as ca1 
    on a.CQDAllowanceId = ca1.CQDAllowanceiD and 
          ca1.ApproveDeclineByType = 'SR' 
  Left Join CQD_SS.dbo.CQDApproval as ca2 
    on a.CQDAllowanceId = ca2.CQDAllowanceiD and 
          ca2.ApproveDeclineByType = 'DM' 
  Left Join CQD_SS.dbo.CQDApproval as ca3 
    on a.CQDAllowanceId = ca3.CQDAllowanceiD and 
          ca3.ApproveDeclineByType = 'EX' 
  Left Join CQD_SS.dbo.CQDApproval as ca4 
    on a.CQDAllowanceId = ca4.CQDAllowanceiD and 
          ca4.ApproveDeclineByType = 'AE' 
  Left Join CQD_SS.dbo.CQDApproval as ca5 
    on a.CQDAllowanceId = ca5.CQDAllowanceiD and 
          ca5.ApproveDeclineByType = 'CE' 
  Left Join CQD_SS.dbo.CQDApproval as ca6 
    on a.CQDAllowanceId = ca6.CQDAllowanceiD and 
          ca6.ApproveDeclineByType = 'SU' 
  Left Join CQD_SS.dbo.CQDApproval as ca7 
    on a.CQDAllowanceId = ca7.CQDAllowanceiD and 
          ca7.ApproveDeclineByType = 'FA') as table_result 
where startPeriod >=202001
group by ProgramType,StartPeriod,FinancialCreditCustomerSite