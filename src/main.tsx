import './index.css'
import { bootRuntime } from '../../packages/runtime/src/boot'
import { version } from '../package.json'

bootRuntime({ version })
