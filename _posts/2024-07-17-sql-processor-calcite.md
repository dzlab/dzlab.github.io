---
layout: post
comments: true
title: Building a SQL processor with Apache Calcite
excerpt: Build a SQL processor for parsing, validating and executing queries with Apache Calcite
categories: database
tags: [calcite,sql]
toc: true
img_excerpt: assets/logos/Apache_Calcite_Logo.svg
---

<img align="center" src="/assets/logos/Apache_Calcite_Logo.svg" />
<br/>

In a [previous article]({{ "database/2024/07/06/apache-calcite/" | absolute_url }}), we saw how to create an Adapter for Apache Calcite and then how to run SQL queries against random data source. In this article we will see in [step by step](https://github.com/zabetak/slides/blob/master/2021/boss-workshop/apache-calcite-tutorial.pdf) how to use Apache Cacite to implement a SQL processor to parse an input query, validate it and then execute it.

**Query**

```sql
SELECT `C_NAME`, `O_ORDERKEY`, `O_ORDERDATE`
FROM `CUSTOMER`
INNER JOIN `ORDERS` ON `CUSTOMER`.`c_custkey` = `ORDERS`.`o_custkey`
WHERE `CUSTOMER`.`c_custkey` < 3
ORDER BY `C_NAME`, `O_ORDERKEY`
```

```java
// TODO 1. Create the root schema and type factory
CalciteSchema schema = CalciteSchema.createRootSchema(false);
RelDataTypeFactory typeFactory = new JavaTypeFactoryImpl();
```
// TODO 2. Create the data type for each TPC-H table
// TODO 3. Add the TPC-H table to the schema
```java
for(TpchTable table: TpchTable.values()) {
  RelDataTypeFactory.Builder builder = typeFactory.builder();
  for(TpchTable.Column c: table.columns) {
    builder.add(c.name, typeFactory.createJavaType(c.type).getSqlTypeName());
  }
  String indexPath = Paths.get(DatasetIndexer.INDEX_LOCATION, "tpch", table.name()).toString();
  schema.add(table.name(), new LuceneTable(indexPath, builder.build()));
}
```

## Query to AST

// TODO 4. Create an SQL parser
```java
SqlParser parser = SqlParser.create(sqlQuery);
```
// TODO 5. Parse the query into an AST
```java
SqlNode parseAst = parser.parseQuery();
// TODO 6. Print and check the AST
System.out.println("[Parsed query]");
System.out.println(parseAst.toString());
```
// TODO 7. Configure and instantiate the catalog reader
```java
CalciteConnectionConfig readerConfig = CalciteConnectionConfig.DEFAULT
        .set(CalciteConnectionProperty.CASE_SENSITIVE, "false");
CalciteCatalogReader catalogReader = new CalciteCatalogReader(schema, Collections.emptyList(), typeFactory,
        readerConfig);
```
// TODO 8. Create the SQL validator using the standard operator table and default configuration
```java
SqlValidator sqlValidator = SqlValidatorUtil.newValidator(SqlStdOperatorTable.instance(),
        catalogReader, typeFactory, SqlValidator.Config.DEFAULT);
```
// TODO 9. Validate the initial AST
```java
SqlNode validAst = sqlValidator.validate(parseAst);
System.out.println("[Validated query");
System.out.println(validAst.toString());
```

## AST to Logical plan

// TODO 10. Create the optimization cluster to maintain planning information
// TODO 11. Configure and instantiate the converter of the AST to Logical plan
// - No view expansion (use NOOP_EXPANDER)
// - Standard expression normalization (use StandardConvertletTable.INSTANCE)
// - Default configuration (SqlToRelConverter.config())
```java
RelOptCluster cluster = newCluster(typeFactory);
SqlToRelConverter sqlToRelConverter = new SqlToRelConverter(NOOP_EXPANDER,
        sqlValidator, catalogReader, cluster,
        StandardConvertletTable.INSTANCE,
        SqlToRelConverter.config());
```
// TODO 12. Convert the valid AST into a logical plan
```java
RelNode logPlan = sqlToRelConverter.convertQuery(validAst, false, true).rel;
// TODO 13. Display the logical plan with explain attributes
System.out.println(
        RelOptUtil.dumpPlan("[Logical plan]", logPlan, SqlExplainFormat.TEXT, SqlExplainLevel.EXPPLAN_ATTRIBUTES)
);
```


**Logical plan**
```
LogicalSort(sort0=[$0], sort1=[$1], dir0=[ASC], dir1=[ASC])
  LogicalProject(C_NAME=[$1], O_ORDERKEY=[$8], O_ORDERDATE=[$12])
    LogicalFilter(condition=[<($0, 3)])
      LogicalJoin(condition=[=($0, $9)], joinType=[inner])
        LogicalTableScan(table=[[CUSTOMER]])
        LogicalTableScan(table=[[ORDERS]])
```

## Logical to Physical plan

// TODO 14. Initialize optimizer/planner with the necessary rules
```java
RelOptPlanner planner = cluster.getPlanner();
planner.addRule(CoreRules.FILTER_TO_CALC);
planner.addRule(CoreRules.PROJECT_TO_CALC);
planner.addRule(EnumerableRules.ENUMERABLE_SORT_RULE);
planner.addRule(EnumerableRules.ENUMERABLE_CALC_RULE);
planner.addRule(EnumerableRules.ENUMERABLE_JOIN_RULE);
planner.addRule(EnumerableRules.ENUMERABLE_TABLE_SCAN_RULE);
```
// TODO 15. Define the type of the output plan (in this case we want a physical plan in
// EnumerableContention)
```java
logPlan = planner.changeTraits(logPlan, logPlan.getTraitSet().replace(EnumerableConvention.INSTANCE));
planner.setRoot(logPlan);

// TODO 16. Start the optimization process to obtain the most efficient physical plan based on
// the provided rule set.
EnumerableRel phyPlan = (EnumerableRel) planner.findBestExp();

// TODO 17. Display the physical plan
System.out.println(
        RelOptUtil.dumpPlan("[Physical plan]", phyPlan, SqlExplainFormat.TEXT, SqlExplainLevel.EXPPLAN_ATTRIBUTES)
);
```

**Physical plan**
```
EnumerableSort(sort0=[$0], sort1=[$1], dir0=[ASC], dir1=[ASC])
  EnumerableCalc(expr#0..16=[{inputs}], C_NAME=[$t1], O_ORDERKEY=[$t8], O_ORDERDATE=[$t12])
    EnumerableCalc(expr#0..16=[{inputs}], expr#17=[3], expr#18=[<($t0, $t17)], proj#0..16=[{exprs}], $condition=[$t18])
      EnumerableHashJoin(condition=[=($0, $9)], joinType=[inner])
        EnumerableTableScan(table=[[CUSTOMER]])
        EnumerableTableScan(table=[[ORDERS]])
```


![Physical Plan](/assets/2024/07/20240717-physical_plan.svg)

## Physical to Executable plan

```
// TODO 18. Compile generated code and obtain the executable program
```java
Bindable<Object[]> execPlan = EnumerableInterpretable.toBindable(new HashMap<>(), null, phyPlan, EnumerableRel.Prefer.ARRAY);
```
// TODO 19. Run the program using a context simply providing access to the schema and print
// results
```java
long start = System.currentTimeMillis();
for(Object[] row: execPlan.bind(new SchemaOnlyDataContext(schema))) {
  System.out.println(Arrays.toString(row));
}
long finish = System.currentTimeMillis();
System.out.println("Elapsed time " + (finish - start) + "ms");
```




## That's all folks
I hope you enjoyed this article, feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc).
