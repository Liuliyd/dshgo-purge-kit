// 把插件名写进 dsh profile 的 package.json：dependencies + dsh.profile.bundles。
// 用法: node profile.mjs <profile 的 package.json> <name...>
import fs from 'node:fs'
import path from 'node:path'

const [pkgPath, ...names] = process.argv.slice(2)
if (!pkgPath || names.length === 0) {
  console.error('usage: node profile.mjs <package.json> <name...>')
  process.exit(2)
}

const raw = fs.readFileSync(pkgPath, 'utf8')
const j = JSON.parse(raw)
const profileDir = path.dirname(pkgPath)

j.dependencies = j.dependencies || {}
j.dsh = j.dsh || {}
j.dsh.profile = j.dsh.profile || {}
const bundles = Array.isArray(j.dsh.profile.bundles) ? j.dsh.profile.bundles : []

for (const name of names) {
  let version = '0.0.0'
  try {
    const p = path.join(profileDir, 'node_modules', name, 'package.json')
    version = JSON.parse(fs.readFileSync(p, 'utf8')).version || version
  } catch {}
  j.dependencies[name] = version
  if (!bundles.includes(name)) bundles.push(name)
  console.log(`  ${name}@${version}`)
}

j.dsh.profile.bundles = bundles
fs.writeFileSync(pkgPath, JSON.stringify(j, null, 2) + '\n')
console.log('bundles =', bundles.join(', '))
