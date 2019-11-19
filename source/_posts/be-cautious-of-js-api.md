---
title: JS采坑记（持续更新）
date: 2019-11-19 11:52:02
tags:
---

## isNaN

| value |  全局isNaN   | Number.isNaN  | Lodash.isNaN |
| ----  |   ----      | ----          | ----         |
| NaN   |  true       | true          | true          |
| 1     | false       | false         | false        |
| "1"   | false       | false         | false        |
| "A string"  | true  | false         | false        |
| undefined  | true   | false         | false        |
| {}    | true        | false         | false        |


## typeof

| value         |  typeof           | 
| ----          |   ----            |  
| NaN           |  'number'         | 
| 1             |  'number'         | 
| {}            |  'object'         |
| []            |  'object'         | 
| null          |  'object'         |
| undefined     |  'undefined'      | 
| 'string'      |  'string'         | 
| tree          |  'boolean'        | 
| (function(){})|  'function'       | 
| (()=>{})      |  'function'       | 