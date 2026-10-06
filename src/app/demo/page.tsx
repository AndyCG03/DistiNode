import type { Metadata } from "next";
import { DemoLoader } from "./DemoLoader";

export const metadata: Metadata = {
  title: "Demo",
  description: "Prueba DistiNode sin cuenta: diseña un sistema distribuido y míralo funcionar.",
};

export default function DemoPage() {
  return <DemoLoader />;
}
