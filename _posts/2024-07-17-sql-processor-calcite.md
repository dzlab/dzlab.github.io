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

As an example query we will use the following simple `JOIN` query between two tables `customer` and `orders`.

```sql
SELECT `C_NAME`, `O_ORDERKEY`, `O_ORDERDATE`
FROM `CUSTOMER`
INNER JOIN `ORDERS` ON `CUSTOMER`.`c_custkey` = `ORDERS`.`o_custkey`
WHERE `CUSTOMER`.`c_custkey` < 3
ORDER BY `C_NAME`, `O_ORDERKEY`
```

## Catalog
We need to build the catalog of metadata for Caclite to resolve the query.

First, we need to create the root schema and type factory:

```java
CalciteSchema schema = CalciteSchema.createRootSchema(false);
RelDataTypeFactory typeFactory = new JavaTypeFactoryImpl();
```

Then, create the metadata of the two tables (columns and data types) then register them with the root schema

```java
RelDataTypeFactory.Builder builder1 = typeFactory.builder();
builder1.add("c_custkey", typeFactory.createJavaType(Integer.class).getSqlTypeName());
builder1.add("c_name", typeFactory.createJavaType(String.class).getSqlTypeName());
schema.add("customer", new MyTable(builder1.build(), ...){...});

RelDataTypeFactory.Builder builder2 = typeFactory.builder();
builder2.add("o_orderkey", typeFactory.createJavaType(Integer.class).getSqlTypeName());
builder2.add("o_custkey", typeFactory.createJavaType(Integer.class).getSqlTypeName());
builder2.add("o_orderdate", typeFactory.createJavaType(Date.class).getSqlTypeName());
schema.add("orders", new MyTable(builder2.build(), ...){...});
```

> Note: `MyTable` should be replaced with the actual class used to access the data and implements Calcite's `Table` / `ScannableTable`

After that, Configure and instantiate a catalog reader that Calcite can use to access the metadata

```java
CalciteConnectionConfig readerConfig = CalciteConnectionConfig.DEFAULT
        .set(CalciteConnectionProperty.CASE_SENSITIVE, "false");
CalciteCatalogReader catalogReader = new CalciteCatalogReader(schema, Collections.emptyList(), typeFactory, readerConfig);
```

> Note: we set the case-sensitivity to false so that we it is OK to user all uppercase table or column names.

## Query to AST
To parse the text query into an Abstract Syntax Tree (AST), we first create a SQL parser

```java
SqlParser parser = SqlParser.create(sqlQuery);
```

Then, we can use it to parse the query into an AST as follows:

```java
SqlNode parseAst = parser.parseQuery();
```

We can get back the original query from the AST with `parseAst.toString()`.


Once we have the AST, we can validate it against the catalog.
First, create a SQL validator using the standard operator table and default configuration.

```java
SqlValidator sqlValidator = SqlValidatorUtil.newValidator(SqlStdOperatorTable.instance(),
        catalogReader, typeFactory, SqlValidator.Config.DEFAULT);
```

Now we can validate the initial AST:

```java
SqlNode validAst = sqlValidator.validate(parseAst);
```

Similarly to before, we can get back the original query from the validated AST with `validAst.toString()`

## AST to Logical plan
Query optimization cannot be applied to an AST, the later must be converted to Relational Algebra expression.


First, Create the optimization cluster to maintain planning information

```java
RelOptPlanner planner = new VolcanoPlanner();
planner.addRelTraitDef(ConventionTraitDef.INSTANCE);
RelOptCluster cluster =  RelOptCluster.create(planner, new RexBuilder(typeFactory));
```

Then, Configure and instantiate an AST to Logical plan converter with default configuration and Standard expression normalization

```java
RelOptTable.ViewExpander NOOP_EXPANDER = (type, query, schema, path) -> null;
SqlToRelConverter sqlToRelConverter = new SqlToRelConverter(NOOP_EXPANDER,
        sqlValidator, catalogReader, cluster,
        StandardConvertletTable.INSTANCE,
        SqlToRelConverter.config());
```

Now, we can convert the validated AST into a logical plan and print it to standard output
```java
RelNode logPlan = sqlToRelConverter.convertQuery(validAst, false, true).rel;
// TODO 13. Display the logical plan with explain attributes
System.out.println(
        RelOptUtil.dumpPlan("[Logical plan]", logPlan, SqlExplainFormat.TEXT, SqlExplainLevel.EXPPLAN_ATTRIBUTES)
);
```

We should see a **Logical plan** that look like this:

```
LogicalSort(sort0=[$0], sort1=[$1], dir0=[ASC], dir1=[ASC])
  LogicalProject(C_NAME=[$1], O_ORDERKEY=[$8], O_ORDERDATE=[$12])
    LogicalFilter(condition=[<($0, 3)])
      LogicalJoin(condition=[=($0, $9)], joinType=[inner])
        LogicalTableScan(table=[[CUSTOMER]])
        LogicalTableScan(table=[[ORDERS]])
```

## Logical to Physical plan
We need to optimize the Logical Plan and convert it to a plan that can be executed by the underlying storage system.

First, initialize optimizer/planner with the necessary rules that will be used to transform the Logical Plan:

```java
RelOptPlanner planner = cluster.getPlanner();
planner.addRule(CoreRules.FILTER_TO_CALC);
planner.addRule(CoreRules.PROJECT_TO_CALC);
planner.addRule(EnumerableRules.ENUMERABLE_SORT_RULE);
planner.addRule(EnumerableRules.ENUMERABLE_CALC_RULE);
planner.addRule(EnumerableRules.ENUMERABLE_JOIN_RULE);
planner.addRule(EnumerableRules.ENUMERABLE_TABLE_SCAN_RULE);
```

Next, define the type of the output plan, in this case we want a physical plan in `EnumerableContention`

```java
logPlan = planner.changeTraits(logPlan, logPlan.getTraitSet().replace(EnumerableConvention.INSTANCE));
planner.setRoot(logPlan);
```

Start the optimization process to obtain the most efficient physical plan based on the provided rule set.

```java
EnumerableRel phyPlan = (EnumerableRel) planner.findBestExp();
```

We can visualize the **Physical plan**

```java
System.out.println(
        RelOptUtil.dumpPlan("[Physical plan]", phyPlan, SqlExplainFormat.TEXT, SqlExplainLevel.EXPPLAN_ATTRIBUTES)
);
```

Which will give us something like this:

```
EnumerableSort(sort0=[$0], sort1=[$1], dir0=[ASC], dir1=[ASC])
  EnumerableCalc(expr#0..16=[{inputs}], C_NAME=[$t1], O_ORDERKEY=[$t8], O_ORDERDATE=[$t12])
    EnumerableCalc(expr#0..16=[{inputs}], expr#17=[3], expr#18=[<($t0, $t17)], proj#0..16=[{exprs}], $condition=[$t18])
      EnumerableHashJoin(condition=[=($0, $9)], joinType=[inner])
        EnumerableTableScan(table=[[CUSTOMER]])
        EnumerableTableScan(table=[[ORDERS]])
```

Or generate a [Dotviz graph](graphviz.org) which would look like this:

![Physical Plan](/assets/2024/07/20240717-physical_plan.svg)

## Physical to Executable plan
```java
/**
 * A simple data context only with schema information.
 */
private static final class SchemaOnlyDataContext implements DataContext {
  private final SchemaPlus schema;

  SchemaOnlyDataContext(CalciteSchema calciteSchema) {
    this.schema = calciteSchema.plus();
  }

  @Override public SchemaPlus getRootSchema() {
    return schema;
  }

  @Override public JavaTypeFactory getTypeFactory() {
    return new JavaTypeFactoryImpl();
  }

  @Override public QueryProvider getQueryProvider() {
    return null;
  }

  @Override public Object get(final String name) {
    return null;
  }
}
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
